import Foundation
import UIKit
import core
import hw
import greenaddress

enum SubaccountAction {
    case created
    case unarchived
}

class CreateAccountViewModel {
    var asset: String?
    var anyLiquidAsset: Bool = false
    var anyLiquidAmpAsset: Bool = false
    var anyLiquidAmpLegacyAsset: Bool = false
    var onlyBtc: Bool = false
    var assetCellModel: AssetSelectCellModel? {
        if anyLiquidAmpAsset {
            return AssetSelectCellModel(anyAmp: true)
        } else if anyLiquidAmpLegacyAsset {
            return AssetSelectCellModel(anyAmpLegacy: true)
        } else if anyLiquidAsset {
            return AssetSelectCellModel(anyLiquid: true)
        } else if let asset = asset {
            return AssetSelectCellModel(assetId: asset, satoshi: 0)
        }
        return nil
    }
    var wm: WalletManager { WalletManager.current! }

    init(asset: String? = nil,
         anyLiquidAsset: Bool = false,
         anyLiquidAmpAsset: Bool = false,
         anyLiquidAmpLegacyAsset: Bool = false,
         onlyBtc: Bool = false) {
        self.asset = asset
        self.anyLiquidAsset = anyLiquidAsset
        self.anyLiquidAmpAsset = anyLiquidAmpAsset
        self.anyLiquidAmpLegacyAsset = anyLiquidAmpLegacyAsset
        self.onlyBtc = onlyBtc
    }

    var unarchiveCreateDialog: (( @escaping (Bool) -> Void) -> Void)?
    var isAllPoliciesShown = false

    private var supportsLiquidTwoFactor: Bool {
        // Ledger cannot log in to a new Liquid GDK session. An existing Liquid
        // multisig backend means the account-creation flow is already supported.
        return !wm.isLedger || wm.hasLiquidMultisig
    }

    func listBitcoin(extended: Bool) -> [AccountTypeOption] {
        var policies: [AccountTypeOption] = [.NativeSegwit, .TwoOfThreeWith2FA, .TwoFAProtected]
        if extended {
            policies.append(.LegacySegwit)
        }
        return policies
    }

    func listLiquid(extended: Bool) -> [AccountTypeOption] {
        var policies: [AccountTypeOption] = [.NativeSegwit]
        if supportsLiquidTwoFactor {
            policies.append(.TwoFAProtected)
        }
        if extended {
            policies.append(.LegacySegwit)
        }
        return policies
    }

    func isAdvancedEnable() -> Bool {
        if anyLiquidAmpAsset || anyLiquidAmpLegacyAsset { // any amp liquid asset
            return false
        } else if let asset = asset, let asset = WalletManager.current?.info(for: asset), asset.amp ?? false { // amp liquid asset
            return false
        }
        return true
    }

    func resetSelection() {
        anyLiquidAsset = false
        anyLiquidAmpAsset = false
        anyLiquidAmpLegacyAsset = false
    }

    func hasLightning() -> Bool {
        return wm.hasLightning
    }

    func getAccountCellModels() -> [AccountTypeCellModel] {
        let policies = policiesForAsset(extended: isAllPoliciesShown)
        return policies.map { AccountTypeCellModel.from(policy: $0) }
    }

    func policiesForAsset(extended: Bool) -> [AccountTypeOption] {
        if anyLiquidAmpAsset || anyLiquidAmpLegacyAsset { // any amp liquid asset
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

    func create(policy: AccountTypeOption, params: CreateSubaccountParams) async throws -> SubaccountAction {
        let isLiquid = anyLiquidAsset || anyLiquidAmpAsset || anyLiquidAmpLegacyAsset || asset != "btc"
        let network = policy.getNetwork(testnet: wm.testnet, liquid: isLiquid)!
        let backend = try wm.gdkNetworkBackend(network)
        let session = backend.session
        if !session.logged {
            if wm.isHW {
                try await loginHW(backend: backend)
            } else {
                try await loginCredentials(backend: backend)
            }
        }
        backend.isLoggedIn = session.logged
        let action = try await self.createOrUnarchiveSubaccount(session: session, params: params)
        let subaccounts = try await self.wm.getAccounts()
        _ = try await self.wm.balances(subaccounts: subaccounts)
        return action
    }

    func loginHW(backend: GdkNetworkBackend) async throws {
        let session = backend.session
        guard let wallet = WalletsStorage.shared.current else {
            throw GaError.GenericError("No account provided")
        }
        if session.gdkNetwork.liquid && wallet.isLedger {
            throw GaError.GenericError("Liquid not supported on Ledger Nano X")
        }
        let hw = wallet.isJade ? HWDevice.defaultJade(fmwVersion: nil) : HWDevice.defaultLedger()
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
        backend.isLoggedIn = session.logged
        let subaccounts = try await session.subaccounts(true)
        let used = try await self.isUsedDefaultAccount(for: session, account: subaccounts.first)
        if !used {
            let params = UpdateSubaccountParams(subaccount: 0, hidden: true)
            try await session.updateSubaccount(params)
        }
        _ = try await wm.getAccounts()
    }

    func loginCredentials(backend: GdkNetworkBackend) async throws {
        let session = backend.session
        let prominentSession = wm.prominentSession
        guard let credentials = try await prominentSession?.getCredentials(password: "") else {
            throw GaError.GenericError("No credential provided")
        }
        try await session.register(credentials: credentials)
        _ = try await session.loginUser(credentials)
        backend.isLoggedIn = session.logged
        let subaccounts = try await session.subaccounts(true)
        let used = try await self.isUsedDefaultAccount(for: session, account: subaccounts.first)
        if !used {
            let params = UpdateSubaccountParams(subaccount: 0, hidden: true)
            try await session.updateSubaccount(params)
        }
        _ = try await wm.getAccounts()
    }

    func isUsedDefaultAccount(for session: SessionManager, account: Account?) async throws -> Bool {
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
        let accounts = self.wm.accounts.filter { $0.gdkNetwork == session.gdkNetwork && $0.type == params.type && $0.type != .twoOfThree && $0.hidden }
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

    func uniqueName(_ type: AccountType, liquid: Bool) -> String {
        let network = liquid ? " Liquid " : " "
        let counter = wm.accounts.filter { $0.type == type && $0.gdkNetwork.liquid == liquid }.count
        if counter > 0 {
            return "\(type.string)\(network)\(counter+1)"
        }
        return "\(type.string)\(network)"
    }
}
