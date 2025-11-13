import Foundation
import UIKit
import core
import gdk
import hw
import greenaddress

enum SubaccountAction {
    case created
    case unarchived
}
class SecuritySelectViewModel {

    var asset: String?
    var anyLiquidAsset: Bool = false
    var anyLiquidAmpAsset: Bool = false
    var onlyBtc: Bool = false
    var assetCellModel: AssetSelectCellModel? {
        if anyLiquidAmpAsset {
            return AssetSelectCellModel(anyAmp: true)
        } else if anyLiquidAsset {
            return AssetSelectCellModel(anyLiquid: true)
        } else if let asset = asset {
            return AssetSelectCellModel(assetId: asset, satoshi: 0)
        }
        return nil
    }
    private var wm: WalletManager { WalletManager.current! }

    init(asset: String? = nil, anyLiquidAsset: Bool = false, anyLiquidAmpAsset: Bool = false, onlyBtc: Bool = false) {
        self.asset = asset
        self.anyLiquidAsset = anyLiquidAsset
        self.anyLiquidAmpAsset = anyLiquidAmpAsset
        self.onlyBtc = onlyBtc
    }

    var unarchiveCreateDialog: (( @escaping (Bool) -> Void) -> Void)?

    var showAll = false
    var hasBTCMultisig: Bool { wm.hasBTCMultisig }
    var hasLiquidMultisig: Bool { wm.hasMultisig }

    func listBitcoin(extended: Bool) -> [PolicyCellType] {
        var list: [PolicyCellType] = [.NativeSegwit, .LegacySegwit, .TwoFAProtected, .TwoOfThreeWith2FA]
        if !extended {
            list = [.NativeSegwit, .LegacySegwit]
        }
        return list
    }

    func listLiquid(extended: Bool) -> [PolicyCellType] {
        var list: [PolicyCellType] = [.NativeSegwit, .LegacySegwit, .TwoFAProtected]
        if !extended {
            list = [.NativeSegwit, .LegacySegwit]
        }
        return list
    }

    func isAdvancedEnable() -> Bool {
        if anyLiquidAmpAsset { // any amp liquid asset
            return false
        } else if anyLiquidAsset { // any liquid asset
            return hasLiquidMultisig
        } else if AssetInfo.btcId == asset { // btc
            return hasBTCMultisig
        } else if let asset = asset, let asset = WalletManager.current?.info(for: asset), asset.amp ?? false { // amp liquid asset
            return false
        } else { // liquid
            return hasLiquidMultisig
        }
    }

    func resetSelection() {
        anyLiquidAsset = false
        anyLiquidAmpAsset = false
    }

    func hasLightning() -> Bool {
        return wm.lightningSubaccount != nil
    }

    /// cell models
    func getPolicyCellModels() -> [PolicyCellModel] {
        let policies = policiesForAsset(extended: showAll)
        return policies.map { PolicyCellModel.from(policy: $0) }
    }

    func policiesForAsset(extended: Bool) -> [PolicyCellType] {
        if anyLiquidAmpAsset { // any amp liquid asset
            return [.Amp]
        } else if anyLiquidAsset { // any liquid asset
            return listLiquid(extended: extended)
        } else if AssetInfo.btcId == asset { // btc
            return listBitcoin(extended: extended)
        } else if let asset = asset, let asset = WalletManager.current?.info(for: asset), asset.amp ?? false { // amp liquid asset
            return [.Amp]
        } else { // liquid
            return listLiquid(extended: extended)
        }
    }

    func create(policy: PolicyCellType, params: CreateSubaccountParams) async throws -> SubaccountAction {
        let isLiquid = anyLiquidAsset || anyLiquidAmpAsset || asset != "btc"
        let network = policy.getNetwork(testnet: wm.testnet, liquid: isLiquid)!
        guard let session = getSession(for: network) else {
            throw GaError.GenericError("id_invalid_session".localized)
        }
        if !session.logged {
            if wm.isHW {
                try await loginHW(session: session)
            } else {
                try await loginCredentials(session: session)
            }
        }
        let action = try await self.createOrUnarchiveSubaccount(session: session, params: params)
        let subaccounts = try await self.wm.subaccounts()
        _ = try await self.wm.balances(subaccounts: subaccounts)
        return action
    }

    func loginHW(session: SessionManager) async throws {
        guard let account = AccountsRepository.shared.current else {
            throw GaError.GenericError("No account provided")
        }
        if session.gdkNetwork.liquid && account.isLedger {
            throw GaError.GenericError("Liquid not supported on Ledger Nano X")
        }
        let hw = account.isJade ? HWDevice.defaultJade(fmwVersion: nil) : HWDevice.defaultLedger()
        do {
            try await session.register(hw: hw)
            _ = try await session.loginUser(hw)
        } catch {
            switch error {
            case TwoFactorCallError.failure(let txt):
                if txt.contains("HWW must enable host unblinding for singlesig wallets") {
                    try? await session.disconnect()
                    throw LoginError.hostUnblindingDisabled("Account creation is not possible without exporting master blinding key.")
                }
                throw error
            default:
                throw error
            }
        }
        let subaccounts = try await session.subaccounts(true)
        let used = try await self.isUsedDefaultAccount(for: session, account: subaccounts.first)
        if !used {
            let params = UpdateSubaccountParams(subaccount: 0, hidden: true)
            try await session.updateSubaccount(params)
        }
        _ = try await wm.subaccounts()
    }

    func loginCredentials(session: SessionManager) async throws {
        guard let prominentSession = wm.prominentSession else {
            throw GaError.GenericError("No session available")
        }
        guard let credentials = try await prominentSession.getCredentials(password: "") else {
            throw GaError.GenericError("No credential provided")
        }
        try await session.register(credentials: credentials)
        _ = try await session.loginUser(credentials)
        let subaccounts = try await session.subaccounts(true)
        let used = try await self.isUsedDefaultAccount(for: session, account: subaccounts.first)
        if !used {
            let params = UpdateSubaccountParams(subaccount: 0, hidden: true)
            try await session.updateSubaccount(params)
        }
        _ = try await wm.subaccounts()
    }

    func isUsedDefaultAccount(for session: SessionManager, account: WalletItem?) async throws -> Bool {
        guard let account = account else {
            throw GaError.GenericError("No subaccount found")
        }
        if account.gdkNetwork.multisig {
            // check balance for multisig
            let balance = try await session.getBalance(subaccount: account.pointer, numConfs: 0)
            return balance.map { $0.value }.reduce(0, +) > 0
        }
        // check bip44Discovered on singlesig
        return account.bip44Discovered ?? false
    }

    func createOrUnarchiveSubaccount(session: SessionManager, params: CreateSubaccountParams) async throws -> SubaccountAction {
        let accounts = self.wm.subaccounts.filter { $0.gdkNetwork == session.gdkNetwork && $0.type == params.type && $0.type != .twoOfThree && $0.hidden }
        guard let account = accounts.first else {
            _ = try await session.createSubaccount(params)
            return .created
        }

        let createNew = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            if let dialog = unarchiveCreateDialog {
                dialog { create in
                    Task { @MainActor in
                        continuation.resume(returning: create)
                    }
                }
            } else {
                Task { @MainActor in
                    continuation.resume(returning: false)
                }
            }
        }

        if createNew {
            _ = try await session.createSubaccount(params)
            return .created
        } else {
            let updateParams = UpdateSubaccountParams(subaccount: account.pointer, hidden: false)
            try await session.updateSubaccount(updateParams)
            if (try? await session.subaccount(account.pointer)) != nil {
                return .unarchived
            } else {
                throw GaError.GenericError("Failed to unarchive subaccount")
            }
        }
    }

    func getSession(for network: NetworkSecurityCase) -> SessionManager? {
        wm.sessions[network.network]
    }

    func uniqueName(_ type: AccountType, liquid: Bool) -> String {
        let network = liquid ? " Liquid " : " "
        let counter = wm.subaccounts.filter { $0.type == type && $0.gdkNetwork.liquid == liquid }.count
        if counter > 0 {
            return "\(type.string)\(network)\(counter+1)"
        }
        return "\(type.string)\(network)"
    }

    var linkMore: String {
        return "https://help.blockstream.com/hc/en-us/articles/23020279153177"
    }
}
