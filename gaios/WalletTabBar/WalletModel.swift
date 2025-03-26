import Foundation
import UIKit
import gdk
import greenaddress
import hw
import core

enum SecurityState {
    case normal
    case alerted
}
class WalletModel {

    var wm: WalletManager? { WalletManager.current }
    var session: SessionManager? { wm?.prominentSession }
    var settings: Settings? { session?.settings }
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
    var txCellModels = [TransactionCellModel]()
    var balanceCellModel: BalanceCellModel?
    var alertCardCellModel = [AlertCardCellModel]()
    var promoCardCellModel = [PromoCellModel]()

    var walletAssetCellModels: [WalletAssetCellModel] {
        return cachedBalance?
            .nonZeroAmounts()
            .compactMap { WalletAssetCellModel(assetId: $0.0, satoshi: $0.1) } ?? []
    }

    var remoteAlert: RemoteAlert?

    var balanceDisplayMode: BalanceDisplayMode = .denom

    var analyticsDone = false
    var isFirstLoad = false
    var hideBalance: Bool {
        get {
            return UserDefaults.standard.bool(forKey: AppStorageConstants.hideBalance.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: AppStorageConstants.hideBalance.rawValue)
        }
    }

    var page = 0
    var fetchingTxs = false
    var securityState = SecurityState.alerted
    var currency: String? {
        if let settings = settings {
            return settings.pricing["currency"]
        }
        return nil
    }
    init() {
        remoteAlert = RemoteAlertManager.shared.alerts(screen: .walletOverview, networks: wm?.activeNetworks ?? []).first
        if let promo = PromoManager.shared.promoCellModels(.walletOverview).first?.promo,
        let source = PromoManager.shared.promoCellModels(.walletOverview).first?.source {
            PromoManager.shared.promoView(promo: promo, source: source)
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

    func fetchBalances(discovery: Bool) async throws {
        let subaccounts = try await wm?.subaccounts(discovery)
        let balances = try await wm?.balances(subaccounts: subaccounts ?? [])
        self.cachedBalance = AssetAmountList(balances ?? [:])
    }

    func reloadBalances() {
        guard let satoshi = cachedBalance?.satoshi(),
                let cachedBalance = self.cachedBalance else {
            balanceCellModel = nil
            return
        }
        balanceCellModel = BalanceCellModel(satoshi: satoshi,
                                            cachedBalance: cachedBalance,
                                            mode: self.balanceDisplayMode,
                                            assetId: self.getAssetId())
    }

    func fetchTransactions() async throws {
        if fetchingTxs {
            return
        }
        fetchingTxs = true
        let txs = try await wm?.transactionsAll(subaccounts: subaccounts) ?? []
        cachedTransactions = txs.sorted(by: >)
        fetchingTxs = false
    }

    func reloadTransactions() {
        var next = txCellModels.count + 30
        if next > cachedTransactions.count {
            next = cachedTransactions.count
        }
        txCellModels = cachedTransactions.prefix(upTo: next)
            .map { ($0, getNodeBlockHeight(subaccountHash: $0.subaccount!)) }
            .map { TransactionCellModel(tx: $0.0, blockHeight: $0.1) }
    }
    func getTransactions_(restart: Bool = true, max: Int? = nil) async throws -> Bool {

        if fetchingTxs {
            return false
        }
        fetchingTxs = true
        do {
            let txs = try await wm?.transactions(subaccounts: wm?.subaccounts ?? [], first: (restart == true) ? 0 : cachedTransactions.count) ?? []
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

    func getNodeBlockHeight(subaccountHash: Int) -> UInt32 {
        if let subaccount = self.wm?.subaccounts.filter({ $0.hashValue == subaccountHash }).first,
            let network = subaccount.network,
            let session = self.wm?.sessions[network] {
            return session.blockHeight
        }
        return 0
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

    func loadFailureMessage() -> String? {
        guard let wm = wm else { return nil }
        for key in wm.activeSessions.keys {
            if let msg = wm.activeSessions[key]?.gdkFailures.popLast() {
                return msg
            }
        }
        return nil
    }

    func reloadPromoCards() async {
        promoCardCellModel = subaccounts.count == 0 ? [] : PromoManager.shared.promoCellModels(.walletOverview)
    }

    func reloadAlertCards() async {
        guard let wm = wm, let session = session else { return }
        var cards: [AlertCardType] = []
        // All sessions should login with the passphrase
        if wm.account.isEphemeral {
            // Bip39 ephemeral wallet
            cards.append(.ephemeralWallet)
        }
        if session.gdkNetwork.mainnet == false {
            // Testnet wallet
            cards.append(AlertCardType.testnetNoValue)
        }
        // countly alerts
        if let remoteAlert = remoteAlert {
            cards.append(AlertCardType.remoteAlert(remoteAlert))
        }
        // Failure login session
        cards += await wm.failureSessionsError.errors
            .filter {
                switch $0.value {
                case TwoFactorCallError.failure(localizedDescription: let txt):
                    return txt != "id_login_failed"
                default:
                    return true
                }
            }.map { AlertCardType.login($0.key, $0.value) }
        // Load dispute on not wo session
        if !watchOnly {
            cards += self.loadDisputeCards()
        }
        // Load missing princing
        if Balance.fromSatoshi(0, assetId: session.gdkNetwork.getFeeAsset())?.toFiat().0 == "n/a" {
            cards.append(AlertCardType.fiatMissing)
        }
        // Load system messages
        let messages = try? await wm.loadSystemMessages()
        messages?.forEach { msg in
            if !msg.text.isEmpty {
                cards.append(AlertCardType.systemMessage(msg))
            }
        }
        // Load lightning errors
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
        // Load expired 2fa utxos
        let expired = try? await wm.getExpiredSubaccounts()
        if let expired = expired, !expired.isEmpty && !watchOnly {
            expiredSubaccounts = expired
            cards.append(.reEnable2fa)
        }
        self.alertCardCellModel = subaccounts.count == 0 ? [] : cards.map { AlertCardCellModel(type: $0) }
    }

    func reEnable2faViewModel() -> ReEnable2faViewModel {
        ReEnable2faViewModel(expiredSubaccounts: expiredSubaccounts)
    }

    func reload() async {
        try? await fetchBalances(discovery: false)
        reloadBalances()
        try? await fetchTransactions()
        reloadTransactions()
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
        guard let lightningSession = self.wm?.lightningSession,
        lightningSession.logged else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            AppNotifications.shared.requestRemoteNotificationPermissions(application: UIApplication.shared) {
                Task.detached(priority: .background) { [weak self] in
                    let defaults = UserDefaults(suiteName: Bundle.main.appGroup)
                    if let token = defaults?.string(forKey: "token"),
                       let xpubHashId = self?.wm?.account.xpubHashId {
                        lightningSession.registerNotification(token: token, xpubHashId: xpubHashId)
                        if lightningSession.lightBridge?.lspInformation == nil {
                            _ = lightningSession.lightBridge?.updateLspInformation()
                        }
                    }
                }
            }
        }
    }

    func isSendEnabled() async -> Bool {
        if watchOnly {
            let notSinglesigBitcoinNetworks = subaccounts.filter { $0.networkType.multisig || $0.networkType.liquid }
            let credentials = try? await wm?.prominentSession?.getCredentials(password: "")
            let pubkeys = credentials?.slip132ExtendedPubkeys ?? []
            return notSinglesigBitcoinNetworks.isEmpty && pubkeys.isEmpty
        }
        return true
    }

    func isSweepEnabled() -> Bool {
        if watchOnly {
            let notMultisigBitcoinNetworks = subaccounts.filter { $0.networkType.singlesig || $0.networkType.liquid }
            return notMultisigBitcoinNetworks.isEmpty
        }
        return false
    }

    func accountCellModelsBy(_ assetId: String?) -> [AccountCellModel] {
        var accountCellModels = [AccountCellModel]()
        for subaccount in subaccounts {
            let assetId = assetId ?? subaccount.gdkNetwork.policyAsset ?? "btc"
            if subaccount.hasAsset(assetId) {
                let satoshi = subaccount.satoshi?[assetId] ?? 0
                accountCellModels += [AccountCellModel(account: subaccount, satoshi: satoshi, assetId: assetId)]
            }
        }
        return accountCellModels
    }

    func rotateBalanceDisplayMode() async throws {
        var isBTC = false
        if let session = self.session, let settings = session.settings {
            isBTC = settings.denomination == .BTC
        }
        balanceDisplayMode = balanceDisplayMode.next(isBTC)
        reloadBalances()
    }
}
