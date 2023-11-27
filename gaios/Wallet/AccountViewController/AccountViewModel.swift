import Foundation
import UIKit
import gdk
import greenaddress

enum AmpEducationalMode {
    case table
    case header
    case hidden
}

class AccountViewModel {
    var wm: WalletManager? { WalletManager.current }
    var cachedBalance: AssetAmountList
    var cachedTransactions = [Transaction]()
    var account: WalletItem!
    var page = 0
    var fetchingTxs = false

    var showAssets: Bool {
        account.gdkNetwork.liquid
    }

    var watchOnly: Bool {
        wm?.account.isWatchonly ?? false
    }

    var satoshi: Int64 {
        cachedBalance.amounts.first(where: { $0.0 == account.gdkNetwork.getFeeAsset() })?.1 ?? account.btc ?? 0
    }

    var inboundCellModels: [LTInboundCellModel] {
        if isLightning {
            let amount = wm?.lightningSession?.nodeState?.inboundLiquiditySatoshi ?? 0
            return [LTInboundCellModel(amount: amount)]
        }
        return []
    }

    var sweepCellModels: [LTSweepCellModel] {
        let amount = wm?.lightningSession?.nodeState?.onchainBalanceSatoshi
        if isLightning, let amount = amount, amount > 0 {
            return [LTSweepCellModel(amount: amount)]
        }
        return []
    }

    var addingCellModels: [AddingCellModel] {
        let enabled2fa = account.session?.twoFactorConfig?.anyEnabled ?? false
        if account.type == .standard && !enabled2fa && !watchOnly {
            return [AddingCellModel()]
        }
        return []
    }

    var discloseCellModels: [DiscloseCellModel] {
        switch ampEducationalMode {
        case .table:
            return [DiscloseCellModel(title: "id_learn_more_about_amp_the_assets".localized, hint: "id_check_our_6_easy_steps_to_be".localized)]
        default:
            return []
        }
    }

    var isLightning: Bool {
        return account.type == .lightning
    }

    var isLightningShortcut: Bool {
        return AccountsRepository.shared.current?.isDerivedLightning ?? false
    }

    var ampEducationalMode: AmpEducationalMode {
        if account.type != .amp {
            return .hidden
        } else {
            let satoshi = account.satoshi?[account.gdkNetwork.getFeeAsset()] ?? 0
            let assets = cachedBalance.amounts
            if satoshi > 0 || assets.count > 1 {
                return .header
            } else {
                return .table
            }
        }
    }

    var accountCellModels: [AccountCellModel]
    var txCellModels = [TransactionCellModel]()
    var assetCellModels = [WalletAssetCellModel]()

    init(model: AccountCellModel, account: WalletItem, cachedBalance: AssetAmountList) {
        self.accountCellModels = [model]
        self.account = account
        self.cachedBalance = cachedBalance
    }

    func getTransactions(restart: Bool = true, max: Int? = nil) async throws -> Bool {
        if fetchingTxs {
            return false
        }
        fetchingTxs = true
        do {
            let txs = try await wm?.transactions(subaccounts: [account], first: (restart == true) ? 0 : cachedTransactions.count) ?? []
            if txs.count == 0 || txs.sorted(by: >) == cachedTransactions.suffix(txs.count) {
                fetchingTxs = false
                return false
            }
            if restart {
                page = 0
                cachedTransactions = []
            }
            if txs.count > 0 {
                page += 1
            }
            cachedTransactions += txs
            cachedTransactions = Array((cachedTransactions)
                .sorted(by: >)
                .prefix(max ?? cachedTransactions.count))
            txCellModels = cachedTransactions
                .map { ($0, getNodeBlockHeight(subaccountHash: $0.subaccount!)) }
                .map { TransactionCellModel(tx: $0.0, blockHeight: $0.1) }
            fetchingTxs = false
            return true
        } catch {
            print(error)
            fetchingTxs = false
            return false
        }
    }

    func getBalance() async throws {
        if let balances = try? await wm?.balances(subaccounts: [account]) {
            account.satoshi = balances
            cachedBalance = AssetAmountList(balances)
        }
        accountCellModels = [AccountCellModel(account: account, satoshi: satoshi)]
        assetCellModels = cachedBalance.amounts.map { WalletAssetCellModel(assetId: $0.0, satoshi: $0.1) }
    }

    func getNodeBlockHeight(subaccountHash: Int) -> UInt32 {
        if let subaccount = self.wm?.subaccounts.filter({ $0.hashValue == subaccountHash }).first,
           let network = subaccount.network,
           let session = self.wm?.sessions[network] {
            return session.blockHeight
        }
        return 0
    }

    func archiveSubaccount() async throws {
        guard let session = wm?.sessions[account.gdkNetwork.network] else {
            return
        }
        try await session.updateSubaccount(subaccount: account.pointer, hidden: true)
        account = try await wm?.subaccount(account: account)
        accountCellModels = [AccountCellModel(account: account, satoshi: satoshi)]
    }

    func removeLightningSubaccount() async throws {
        let prominentSession = wm?.prominentSession
        let session = wm?.sessions[account.gdkNetwork.network]
        
        // remove lightning shortcut
        let account = AccountsRepository.shared.current
        if let derivedAccount = account?.getDerivedLightningAccount() {
            let derivedCredentials = try AuthenticationTypeHandler.getAuthKeyCredentials(forNetwork: derivedAccount.keychain)
            _ = AuthenticationTypeHandler.removeAuth(method: .AuthKeyCredentials, forNetwork: derivedAccount.keychain)
            if let walletId = session?.walletIdentifier(credentials: derivedCredentials) {
                session?.removeDatadir(walletHashId: walletId.walletHashId)
                LightningRepository.shared.remove(for: walletId.walletHashId)
            }
        }
        
        // remove lightning session
        if let prominentCredentials = try? await prominentSession?.getCredentials(password: ""),
           let lightnigCredentials = wm?.deriveLightningCredentials(from: prominentCredentials),
           let walletId = session?.walletIdentifier(credentials: lightnigCredentials) {
            session?.removeDatadir(walletHashId: walletId.walletHashId)
            LightningRepository.shared.remove(for: walletId.walletHashId)
        }
        try await session?.disconnect()
        _ = try await wm?.subaccounts()
    }

    func renameSubaccount(name: String) async throws {
        guard let session = wm?.sessions[account.gdkNetwork.network] else {
            return
        }
        try await session.renameSubaccount(subaccount: account.pointer, newName: name)
        account = try await wm?.subaccount(account: account)
        accountCellModels = [AccountCellModel(account: account, satoshi: satoshi)]
    }

    func ltRecoverFundsViewModel() -> LTRecoverFundsViewModel {
        LTRecoverFundsViewModel(wallet: account,
                                amount: wm?.lightningSession?.nodeState?.onchainBalanceSatoshi,
                                type: .sweep)
    }

    func ltRecoverFundsViewModel(tx: Transaction) -> LTRecoverFundsViewModel {
        let amount = tx.amounts["btc"].map {UInt64(abs($0))}
        let address = tx.inputs?.first?["address"] as? String
        return LTRecoverFundsViewModel(wallet: account,
                                onChainAddress: address,
                                amount: amount,
                                type: .refund)
    }

    func accountSettingsPrefs() -> [AccountPrefs] {
        AccountPrefs.getPrefs(
            isEphemeral: wm?.account.isEphemeral ?? false || wm?.account.hidden ?? false,
            isHW: wm?.account.isHW ?? false,
            isLightning: isLightning,
            isLightningShortcut: isLightningShortcut,
            switchState: wm?.existDerivedLightning() ?? false)
    }

    func accountSettingsCell() -> [DialogListCellModel] {
        AccountPrefs.getItems(
            isEphemeral: wm?.account.isEphemeral ?? false || wm?.account.hidden ?? false,
            isHW: wm?.account.isHW ?? false,
            isLightning: isLightning,
            isLightningShortcut: isLightningShortcut,
            switchState: wm?.existDerivedLightning() ?? false)
    }

    func existLightningShortcut() -> Bool {
        wm?.existDerivedLightning() ?? false
    }

    func addSWDerivedLightning() async throws {
        guard let mainCredentials = try await wm?.prominentSession?.getCredentials(password: "") else {
            return
        }
        guard let credentials = wm?.deriveLightningCredentials(from: mainCredentials) else {
            return
        }
        try await wm?.addDerivedLightning(credentials: credentials)
    }

    func removeDerivedLightning() async {
        await wm?.removeDerivedLightning()
    }

    var headerIcon: UIImage {
        UIImage(named: wm?.prominentNetwork.gdkNetwork.mainnet == true ? "ic_wallet" : "ic_wallet_testnet")!
        .maskWithColor(color: .white)
    }
}
