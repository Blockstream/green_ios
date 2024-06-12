import Foundation
import UIKit
import gdk
import greenaddress
import hw
import core

class WalletViewModel {

    var wm: WalletManager? { WalletManager.current }
    var session: SessionManager? { wm?.prominentSession }
    var paused: Bool { !(wm?.activeSessions.filter { $0.value.paused }.isEmpty ?? false) }
    var isTxLoading = true // on init is always true
    var isBalanceLoading = true
    var expiredSubaccounts = [WalletItem]()

    /// load visible subaccounts
    var subaccounts: [WalletItem] { wm?.subaccounts.filter { !($0.hidden) } ?? [] }
    var watchOnly: Bool { wm?.account.isWatchonly ?? false}
    var headerIcon: UIImage { return UIImage(named: wm?.prominentNetwork.gdkNetwork.mainnet == true ? "ic_wallet" : "ic_wallet_testnet")!.maskWithColor(color: .white) }

    /// Cached data
    var cachedTransactions = [Transaction]()
    var cachedBalance: AssetAmountList?

    /// if no accounts show the layer
    var welcomeLayerVisibility: (() -> Void)?

    /// expandNewAccount
    var preselectAccount: ((Int) -> Void)?

    /// cell models
    var accountCellModels = [AccountCellModel]()
    var accountLightningCellModels: AccountCellModel? {
        accountCellModels.filter { $0.networkType == .lightning }.first
    }
    var txCellModels = [TransactionCellModel]()
    var balanceCellModel: BalanceCellModel?
    var alertCardCellModel = [AlertCardCellModel]()

    var walletAssetCellModels: [WalletAssetCellModel] {
        return cachedBalance?
            .nonZeroAmounts()
            .compactMap { WalletAssetCellModel(assetId: $0.0, satoshi: $0.1) } ?? []
    }

    var remoteAlert: RemoteAlert?

    var balanceDisplayMode: BalanceDisplayMode = .denom

    var analyticsDone = false

    init() {
        remoteAlert = RemoteAlertManager.shared.alerts(screen: .walletOverview, networks: wm?.activeNetworks ?? []).first
    }

    func loadSubaccounts(discovery: Bool = false) async {
        _ = try? await wm?.subaccounts(discovery)
        self.accountCellModels = self.subaccounts.map { AccountCellModel(account: $0, satoshi: $0.btc) }
    }

    func selectSubaccount(_ newAccount: WalletItem? = nil) {
        if let idx = self.accountCellModels.firstIndex(where: {$0.account == newAccount}) {
            self.preselectAccount?(idx)
        }
    }

    func getAssetId() -> String {
        let lSubs: [WalletItem] = subaccounts.filter { $0.gdkNetwork.liquid == true }
        if lSubs.count == subaccounts.count && lSubs.count > 0 {
            return lSubs.first?.gdkNetwork.mainnet ?? true ? Balance.lbtc : Balance.ltest
        } else {
            return "btc"
        }
    }

    func loadBalances() async throws {
        let balances = try await wm?.balances(subaccounts: self.subaccounts)
        let cachedBalance = AssetAmountList(balances ?? [:])
        self.accountCellModels = subaccounts.map { AccountCellModel(account: $0, satoshi: $0.btc) }
        self.cachedBalance = cachedBalance
        let satoshi = cachedBalance.satoshi()
        balanceCellModel = BalanceCellModel(satoshi: satoshi,
                                            cachedBalance: cachedBalance,
                                            mode: self.balanceDisplayMode,
                                            assetId: self.getAssetId())
        self.welcomeLayerVisibility?()
        self.callAnalytics()
    }

    func loadTransactions(max: Int? = nil) async throws {
        isTxLoading = true
        let txs = try await wm?.transactions(subaccounts: self.subaccounts)
        self.cachedTransactions = Array(txs?.sorted(by: >).prefix(max ?? txs?.count ?? 0) ?? [])
        self.txCellModels = self.cachedTransactions
                    .map { ($0, self.getNodeBlockHeight(subaccountHash: $0.subaccount!)) }
                    .map { TransactionCellModel(tx: $0.0, blockHeight: $0.1) }
        self.isTxLoading = false
    }

    func getNodeBlockHeight(subaccountHash: Int) -> UInt32 {
        if let subaccount = self.wm?.subaccounts.filter({ $0.hashValue == subaccountHash }).first,
            let network = subaccount.network,
            let session = self.wm?.sessions[network] {
            return session.blockHeight
        }
        return 0
    }

    func sumBalances(_ subaccounts: [WalletItem]) -> Int64 {
        var total: Int64 = 0
        for subacc in subaccounts {
            let satoshi = subacc.satoshi?[subacc.gdkNetwork.getFeeAsset()] ?? 0
            if let converted = Balance.fromSatoshi(satoshi, assetId: subacc.gdkNetwork.getFeeAsset()) {
                total += converted.satoshi
            }
        }
        return total
    }

    func rotateBalanceDisplayMode() async throws {
        var isBTC = false
        if let session = self.session, let settings = session.settings {
            isBTC = settings.denomination == .BTC
        }
        balanceDisplayMode = balanceDisplayMode.next(isBTC)
        try await loadBalances()
    }

    func loadDisputeCards() -> [AlertCardType] {
        guard let wm = wm else { return [] }
        var cards: [AlertCardType] = []
        wm.sessions.values.forEach { session in
            if session.logged && session.isResetActive ?? false,
                let twoFaReset = session.twoFactorConfig?.twofactorReset {
                let message = TwoFactorResetMessage(twoFactorReset: twoFaReset, network: session.gdkNetwork.network)
                if twoFaReset.isDisputeActive {
                    cards.append(.dispute(message))
                } else {
                    cards.append(.reset(message))
                }
            }
        }
        return cards
    }

    func loadMetadataCards() -> [AlertCardType] {
        guard let wm = wm else { return [] }
        var cards: [AlertCardType] = []
        // All sessions should login with the passphrase
        if wm.account.isEphemeral {
            // Bip39 ephemeral wallet
            cards.append(.ephemeralWallet)
        }
        if session?.gdkNetwork.mainnet == false {
            // Testnet wallet
            cards.append(AlertCardType.testnetNoValue)
        }
        // countly alerts
        if let remoteAlert = remoteAlert {
            cards.append(AlertCardType.remoteAlert(remoteAlert))
        }
        // Failure login session
        cards += wm.failureSessionsError
            .filter {
                switch $0.value {
                case TwoFactorCallError.failure(localizedDescription: let txt):
                    return txt != "id_login_failed"
                default:
                    return true
                }
            }.map { AlertCardType.login($0.key, $0.value) }
        return cards
    }

    func loadFailureMessage() -> String? {
        guard let wm = wm else { return nil }
        for key in wm.activeSessions.keys {
            if let msg = wm.activeSessions[key]?.gdkFailures.popLast() {
                return msg
            }
        }
        return nil
    }

    func reloadAlertCards() async {
        guard let wm = wm, let session = session else { return }
        var cards: [AlertCardType] = []
        cards += self.loadMetadataCards()
        cards += self.loadDisputeCards()

        if Balance.fromSatoshi(0, assetId: session.gdkNetwork.getFeeAsset())?.toFiat().0 == "n/a" {
            cards.append(AlertCardType.fiatMissing)
        }
        let messages = try? await wm.loadSystemMessages()
        messages?.forEach { msg in
            if !msg.text.isEmpty {
                cards.append(AlertCardType.systemMessage(msg))
            }
        }
        if let lightningSession = wm.lightningSession {
            let res = lightningSession.lightBridge?.serviceHealthCheck()
            switch res?.status {
            case .maintenance:
                cards += [.lightningMaintenance]
            case .serviceDisruption:
                cards += [.lightningServiceDisruption]
            default:
                break
            }
        }
        let expired = try? await wm.getExpiredSubaccounts()
        if let expired = expired, !expired.isEmpty {
            expiredSubaccounts = expired
            cards.append(.reEnable2fa)
        }
        self.alertCardCellModel = cards.map { AlertCardCellModel(type: $0) }
    }

    func reEnable2faViewModel() -> ReEnable2faViewModel {
        ReEnable2faViewModel(expiredSubaccounts: expiredSubaccounts)
    }

    func reload() async {
        await loadSubaccounts()
        try? await loadBalances()
        try? await loadTransactions(max: 20)
    }

    func onCreateAccount(_ wallet: WalletItem) {
        analyticsDone = false
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
            self.selectSubaccount(wallet)
        }
    }

    func reconnectHW(_ network: String) async throws {
        if let account = wm?.account {
            if let jade = BleViewModel.shared.jade {
                _ = try await jade.login(account: account, fullRestore: true)
                _ = try await wm?.subaccounts()
                await reload()
            }
        }
    }

    func callAnalytics() {

        if analyticsDone == true { return }
        analyticsDone = true

        var accountsFunded: Int = 0
        subaccounts.forEach { item in
            let assets = item.satoshi ?? [:]
            for (_, value) in assets where value > 0 {
                    accountsFunded += 1
                    break
            }
        }
        let walletFunded: Bool = accountsFunded > 0
        let accounts: Int = subaccounts.count
        let accountsTypes: String = Array(Set(subaccounts.map { $0.type.rawValue })).sorted().joined(separator: ",")
        AnalyticsManager.shared.activeWalletEnd(account: AccountsRepository.shared.current,
                                                walletData: AnalyticsManager.WalletData(walletFunded: walletFunded,
                                                                                     accountsFunded: accountsFunded,
                                                                                     accounts: accounts,
                                                                                     accountsTypes: accountsTypes))
    }

    func needShortcut() -> Bool {

        guard wm?.lightningSubaccount != nil else {
            return false
        }
        if wm?.existDerivedLightning() == true {
            return false
        }
        if wm?.account.isHW == true {
            return false
        }
        if AccountsRepository.shared.current?.gdkNetwork.mainnet == false {
            return false
        }
        if AccountsRepository.shared.current?.isWatchonly == true {
            return false
        }
        return true
    }

    func addSWDerivedLightning() async throws {

        guard wm?.lightningSubaccount != nil else {
            return
        }

        guard let mainCredentials = try await wm?.prominentSession?.getCredentials(password: "") else {
            return
        }
        guard let credentials = try? wm?.deriveLightningCredentials(from: mainCredentials) else {
            return
        }
        try await wm?.addLightningShortcut(credentials: credentials)
    }

    func registerNotifications() {
        if subaccounts.filter({ $0.networkType == .lightning }).isEmpty {
            return
        }
        DispatchQueue.main.async {
            AppNotifications.shared.requestRemoteNotificationPermissions(application: UIApplication.shared)
        }
    }
}
