import Foundation
import UIKit
import core
import gdk
import hw
import greenaddress


class SecuritySelectViewModel {

    var asset: String? = nil
    var anyLiquidAsset: Bool = false
    var anyLiquidAmpAsset: Bool = false
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

    init(asset: String? = nil, anyLiquidAsset: Bool = false, anyLiquidAmpAsset: Bool = false) {
        self.asset = asset
        self.anyLiquidAsset = anyLiquidAsset
        self.anyLiquidAmpAsset = anyLiquidAmpAsset
    }

    var unarchiveCreateDialog: (( @escaping (Bool) -> ()) -> ())?

    var showAll = false

    func listBitcoin(extended: Bool) -> [PolicyCellType] {
        var list: [PolicyCellType] = [.NativeSegwit, .LegacySegwit, .Lightning, .TwoFAProtected, .TwoOfThreeWith2FA]
        if !extended {
            list = [.NativeSegwit, .Lightning, .TwoFAProtected]
        }
        if !AppSettings.shared.experimental {
            list.removeAll(where: { $0 == .Lightning })
        }
        return list
    }

    func listLiquid(extended: Bool) -> [PolicyCellType] {
        var list:  [PolicyCellType] = [.NativeSegwit, .LegacySegwit, .TwoFAProtected, .Amp]
        if !extended {
            list = [.NativeSegwit, .TwoFAProtected]
        }
        return list
    }
    
    func isAdvancedEnable() -> Bool {
        if anyLiquidAmpAsset {
            return false
        }
        if let asset = asset, let asset = WalletManager.current?.registry.info(for: asset), asset.amp ?? false {
            return false
        } else {
            return true
        }
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
        } else if let asset = asset, let asset = WalletManager.current?.registry.info(for: asset), asset.amp ?? false { // amp liquid asset
            return [.Amp]
        } else { // liquid
            return listLiquid(extended: extended)
        }
    }

    func create(policy: PolicyCellType, params: CreateSubaccountParams?) async throws -> WalletItem? {
        let isLiquid = anyLiquidAsset || anyLiquidAmpAsset || asset != "btc"
        let network = policy.getNetwork(testnet: wm.testnet, liquid: isLiquid)!
        let prominentSession = wm.prominentSession!
        if network.lightning {
            if wm.account.isHW {
                throw GaError.GenericError("Cannot create a lightning account for an hardware wallet")
            }
            guard let session = wm.lightningSession else {
                throw GaError.GenericError("Invalid lightning session")
            }
            if session.logged {
                throw GaError.GenericError("Lightning account already exist")
            }
            try await session.connect()
            guard let mainCredentials = try await prominentSession.getCredentials(password: "") else {
                throw GaError.GenericError()
            }
            let credentials = try wm.deriveLightningCredentials(from: mainCredentials)
            await session.removeDatadir(credentials: credentials)
            let _ = try await session.loginUser(credentials: credentials, hw: nil, restore: true)
            let _ = try await wm.subaccounts()
            if Bundle.main.debug {
                //try await wm.setCloseToAddress()
            }
            return try await session.subaccount(0)
        } else if let session = getSession(for: network) {
            let params = params ?? CreateSubaccountParams(name: uniqueName(policy.accountType, liquid: isLiquid),
                                                          type: policy.accountType,
                                                          recoveryMnemonic: nil,
                                                          recoveryXpub: nil)
            if !session.logged {
                do {
                    try await registerSession(session: session)
                } catch {
                    switch error {
                    case TwoFactorCallError.failure(let txt):
                        if txt.contains("HWW must enable host unblinding for singlesig wallets") {
                            try? await session.disconnect()
                            if let masterXpub = try? await BleViewModel.shared.ledger?.getMasterXpub() {
                                await session.removeDatadir(masterXpub: masterXpub)
                            }
                            throw LoginError.hostUnblindingDisabled("Account creation is not possible without exporting master blinding key.")
                        }
                        throw error
                    default:
                        throw error
                    }
                }
            }
            let accounts = self.wm.subaccounts.filter { $0.gdkNetwork == session.gdkNetwork && $0.type == params.type && $0.type != .twoOfThree && $0.hidden }
            let txs = try await self.wm.transactions(subaccounts: accounts)
            let account = try await self.createOrUnarchiveSubaccount(session: session, accounts: accounts, txs: txs, params: params)
            _ = try await self.wm.subaccounts()
            return account
        } else {
           throw GaError.GenericError("Invalid session")
        }
    }

    func device() -> HWDevice {
        return wm.account.isJade ? .defaultJade(fmwVersion: nil) : .defaultLedger()
    }

    func registerSession(session: SessionManager) async throws {
        if session.gdkNetwork.liquid && wm.account.isLedger {
            throw GaError.GenericError("Liquid not supported on Ledger Nano X")
        } else if wm.account.isHW {
            let hw = wm.account.isJade ? HWDevice.defaultJade(fmwVersion: nil) : HWDevice.defaultLedger()
            return try await registerSession(session: session, hw: hw)
        } else if let prominentSession = wm.prominentSession {
            let credentials = try await prominentSession.getCredentials(password: "")
            return try await registerSession(session: session, credentials: credentials)
        } else {
            throw GaError.GenericError("Invalid session")
        }
    }

    func registerSession(session: SessionManager, credentials: Credentials? = nil, hw: HWDevice? = nil) async throws {
        try await session.register(credentials: credentials, hw: hw)
        _ = try await session.loginUser(credentials: credentials, hw: hw, restore: false)
        let subaccounts = try await session.subaccounts(true)
        let used = try await self.isUsedDefaultAccount(for: session, account: subaccounts.first)
        if !used {
            try await session.updateSubaccount(subaccount: 0, hidden: true)
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

    func createOrUnarchiveSubaccount(session: SessionManager, accounts: [WalletItem], txs: [Transaction], params: CreateSubaccountParams) async throws -> WalletItem? {
        let items = accounts.map { account in
            (account, txs.filter { $0.subaccount == account.hashValue }.count)
        }
        let unfunded = items.filter { $0.1 == 0 }.map { $0.0 }.first
        if let unfunded = unfunded {
            // automatically unarchive it
            try await session.updateSubaccount(subaccount: unfunded.pointer, hidden: false)
            return try await session.subaccount(unfunded.pointer)
        }
        let funded = items.filter { $0.1 > 0 }.map { $0.0 }.first
        if let funded = funded, let dialog = self.unarchiveCreateDialog {
            // ask user to unarchive o create a new one
            dialog() { create in
                Task {
                    if create {
                        try? await session.createSubaccount(params)
                    } else {
                        try? await session.updateSubaccount(subaccount: funded.pointer, hidden: false)
                        try? await session.subaccount(funded.pointer)
                    }
                }
            }
            return nil
        }
        // automatically create a new account
        return try await session.createSubaccount(params)
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

    func addSWShortcutLightning() async throws {
        guard let mainCredentials = try await wm.prominentSession?.getCredentials(password: "") else {
            return
        }
        let credentials = try wm.deriveLightningCredentials(from: mainCredentials)
        try await wm.addLightningShortcut(credentials: credentials)
    }

    func addHWShortcutLightning(_ credentials: Credentials) async throws {
        try await wm.addLightningShortcut(credentials: credentials)
    }

    var linkMore: String {
        return "https://help.blockstream.com/hc/en-us/articles/23020279153177"
    }
}
