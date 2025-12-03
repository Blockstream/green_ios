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
    var mainAccount: Account? { AccountsRepository.shared.current }
    var session: SessionManager? { wm?.prominentSession }
    var settings: Settings? { session?.settings }
    var paused: Bool { !(wm?.activeSessions.filter { $0.value.paused }.isEmpty ?? false) }
    var isTxLoading = true // on init is always true
    var isBalanceLoading = true
    var expiredSubaccounts = [WalletItem]()

    /// load visible subaccounts
    var subaccounts: [WalletItem] { wm?.subaccounts.filter { !($0.hidden) } ?? [] }
    var watchOnly: Bool { wm?.isWatchonly ?? false}
    var headerIcon: UIImage { return UIImage(named: wm?.prominentNetwork.gdkNetwork.mainnet == true ? "ic_wallet" : "ic_wallet_testnet")!.maskWithColor(color: .white) }

    /// Cached data
    var cachedTransactions = [String: [Transactions]]()
    var cachedBalance: AssetAmountList?
    var cachedMeldTransactions = [Transaction]()

    /// if no accounts show the layer
    var welcomeLayerVisibility: (() -> Void)?

    /// cell models
    var txCellModels = [TransactionCellModel]()
    var balanceCellModel: BalanceCellModel?
    var backupCardCellModel = [AlertCardCellModel]()
    var alertCardCellModel = [AlertCardCellModel]()
    var promoCardCellModel = [PromoCellModel]()
    
    var walletAssetCellModels: [WalletAssetCellModel] {
        return cachedBalance?
            .nonZeroAmounts()
            .compactMap { WalletAssetCellModel(assetId: $0.0, satoshi: $0.1, masked: hideBalance, hidden: false) } ?? []
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
        if let promo = PromoManager.shared.promoCellModels(.homeTab).first?.promo,
           let source = PromoManager.shared.promoCellModels(.homeTab).first?.source {
            PromoManager.shared.promoView(promo: promo, source: source)
        }
    }

    func getAssetId() -> String {
        let lSubs: [WalletItem] = subaccounts.filter { $0.gdkNetwork.liquid == true }
        if lSubs.count == subaccounts.count && lSubs.count > 0 {
            return lSubs.first?.gdkNetwork.mainnet ?? true ? AssetInfo.lbtcId : AssetInfo.ltestId
        } else {
            return "btc"
        }
    }

    func fetchBalances(discovery: Bool) async throws {
        var subaccounts: [WalletItem] = try await wm?.subaccounts(discovery) ?? []
        let balances = try await wm?.balances(subaccounts: subaccounts)
        for subaccount in subaccounts {
            if subaccount.hidden == true && accountIsFunded(subaccount) {
                try await unarchiveSubaccount(subaccount)
            }
            if isFirstLoad == true && subaccount.hidden == false && subaccount.type == .segwitWrapped && !accountIsFunded(subaccount) {
                try await archiveSubaccount(subaccount)
            }
        }
        isFirstLoad = false
        subaccounts = try await wm?.subaccounts(false) ?? []
        if let balances = balances {
            cachedBalance = AssetAmountList(balances)
        }
        self.callAnalytics(subaccounts)
    }
    func accountIsFunded(_ subaccount: WalletItem) -> Bool {
        if let satoshi = subaccount.satoshi {
            for (_, v) in satoshi where v > 0 {
                return true
            }
        }
        return false
    }
    func unarchiveSubaccount(_ subaccount: WalletItem) async throws {
        guard let session = WalletManager.current?.sessions[subaccount.gdkNetwork.network] else { return }
        let params = UpdateSubaccountParams(subaccount: subaccount.pointer, hidden: false)
        try? await session.updateSubaccount(params)
    }
    func archiveSubaccount(_ account: WalletItem) async throws {
        guard let session = wm?.sessions[account.gdkNetwork.network] else { return }
        let params = UpdateSubaccountParams(subaccount: account.pointer, hidden: true)
        try await session.updateSubaccount(params)
    }
    func reloadBalances() {
        if let cachedBalance = self.cachedBalance {
            balanceCellModel = BalanceCellModel(satoshi: cachedBalance.satoshi(),
                                                cachedBalance: cachedBalance,
                                                mode: self.balanceDisplayMode,
                                                assetId: self.getAssetId())
        }
    }
    
    func existPendingTransaction() -> Bool {
        let list = cachedTransactions
            .flatMap({$0.value })
            .flatMap({$0.list})
        for tx in list where tx.blockHeight == 0 {
            return true
        }
        return false
    }
    
    func fetchTransactions(reset: Bool) async throws {
        guard let wm = wm, !fetchingTxs else {
            return
        }
        fetchingTxs = true
        // get gdk/lightning transactions
        let txs = try await wm.pagedTransactions(subaccounts: wm.subaccounts, of: reset ? 0 : pages)
        if reset {
            cachedTransactions = [:]
        }
        for (account, pagetxs) in txs {
            cachedTransactions[account] = (cachedTransactions[account] ?? []) + [pagetxs]
        }
        // get meld transactions
        if let cachedMeldTransactions = try? await getMeldTransactions(wm.bitcoinSubaccounts.first) {
            self.cachedMeldTransactions = cachedMeldTransactions
        }
        fetchingTxs = false
    }
    func getMeldTransactions(_ subaccount: WalletItem?) async throws -> [Transaction] {
        guard let subaccount else {
            return []
        }
        if let xpub = mainAccount?.xpubHashId, Meld.needFetchingTxs(xpub: xpub) {
            let meld = Meld()
            let meldTxs = try? await meld.getPendingTransactions(xpub: xpub)
            if let meldTxs = meldTxs {
                Meld.enableFetchingTxs(xpub: xpub, enable: !meldTxs.isEmpty)
                let cachedMeldTransactions = meldTxs.map({ Transaction($0.details, subaccountId: subaccount.id) })
                logger.info("cachedMeldTransactions")
                logger.info("\(self.cachedMeldTransactions.debugDescription)")
                return cachedMeldTransactions
            }
        }
        return []
    }
    var pages: Int {
        return self.cachedTransactions.mapValues({$0.count}).values.max() ?? 0
    }
    func reloadTransactions() {
        let txs = cachedTransactions
            .flatMap({$0.value})
            .flatMap({$0.list})
        let list = Array(txs + cachedMeldTransactions)
            .sorted(by: >)
            .prefix(pages * 30)
        txCellModels = list
            .map { tx in
                let blockHeight = tx.isLiquid ? wm?.liquidBlockHeight() : wm?.bitcoinBlockHeight()
                return TransactionCellModel(tx: tx, blockHeight: blockHeight ?? 0)
            }
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
    func reloadPromoCards() {
        promoCardCellModel = subaccounts.count == 0 ? [] : PromoManager.shared.promoCellModels(.homeTab)
    }
    func reloadBackupCards() {
        guard let wm = wm else { return }
        var cards: [AlertCardType] = []
        if BackupHelper.shared.needsBackup(walletId: AccountsRepository.shared.current?.id) &&
            BackupHelper.shared.isDismissed(walletId: AccountsRepository.shared.current?.id, position: .homeTab) == false &&
            cachedBalance?.satoshi() ?? 0 > 0 {
            cards.append(.backup)
        }
        self.backupCardCellModel = subaccounts.count == 0 ? [] : cards.map { AlertCardCellModel(type: $0) }
    }
    func reloadAlertCards() async {
        guard let wm = wm, let session = session else { return }
        var cards: [AlertCardType] = []
        // All sessions should login with the passphrase
        if mainAccount?.isEphemeral ?? false {
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
    func callAnalytics(_ subs: [WalletItem]?) {
        
        guard let subs else { return }
        if analyticsDone == true { return }
        analyticsDone = true
        
        var accountsFunded: Int = 0
        subs.forEach { item in
            let assets = item.satoshi ?? [:]
            for (_, value) in assets where value > 0 {
                accountsFunded += 1
                break
            }
        }
        let walletFunded: Bool = accountsFunded > 0
        let accounts: Int = subs.count
        let accountsTypes: String = Array(Set(subs.map { $0.type.rawValue })).sorted().joined(separator: ",")
        AnalyticsManager.shared.activeWalletEnd(account: AccountsRepository.shared.current,
                                                walletData: AnalyticsManager.WalletData(walletFunded: walletFunded,
                                                                                        accountsFunded: accountsFunded,
                                                                                        accounts: accounts,
                                                                                        accountsTypes: accountsTypes))
    }
    func registerNotifications() async throws {
        guard let token = UserDefaults(suiteName: Bundle.main.appGroup)?.string(forKey: "token") else {
            throw GaError.GenericError("No token")
        }
        guard let xpubHashId = mainAccount?.xpubHashId else {
            throw GaError.GenericError("No xpub")
        }
        /// Register notification token for meld and lwk on sanbox
        if Bundle.main.dev || Meld.isSandboxEnvironment {
            try? await Meld().registerToken(fcmToken: token, externalCustomerId: xpubHashId, notificationUrl: Meld.MELD_NOTIFICATIONS_URL_SANDBOX)
        }
        /// Register notification token for meld and lwk on production
        if !Bundle.main.dev || !Meld.isSandboxEnvironment {
            try? await Meld().registerToken(fcmToken: token, externalCustomerId: xpubHashId, notificationUrl: Meld.MELD_NOTIFICATIONS_URL_PRODUCTION)
        }
        /// Register notification token for breez lightning
        if let lightningSession = wm?.lightningSession, lightningSession.logged {
            try? await lightningSession.registerNotification(token: token, xpubHashId: xpubHashId)
            _ = lightningSession.lightBridge?.updateLspInformation()
        }
    }
    func completePendingSwap(_ swap: BoltzSwap, accountName: String) async {
        logger.info("completePendingSwap \(swap.id ?? "", privacy: .public): \(swap.data?[0..<64] ?? "")")
        switch swap.type {
        case .some(BoltzSwapTypes.Submarine):
            if let pay = try? await wm?.lwkSession?.restorePreparePay(data: swap.data ?? "") {
                let state = try? await wm?.lwkSession?.handlePay(pay: pay)
            }
        case .some(BoltzSwapTypes.ReverseSubmarine):
            if let invoice = try? await wm?.lwkSession?.restoreInvoice(data: swap.data ?? "") {
                let state = try? await wm?.lwkSession?.handleInvoice(invoice: invoice)
                logger.info("WalletModel \(swap.id ?? "", privacy: .public) \(state?.localized ?? "", privacy: .public)")
                switch state {
                case .success:
                    await DropAlert().success(message: "id_payment_received".localized)
                default:
                    break
                }
            }
        case .none:
            break
        }
    }
    func completePendingSwaps() async {
        let account = AccountsRepository.shared.current
        let pendingSwapsIds = try? await BoltzController.shared.fetchIDs(byIsPending: true, byXpubHashId: account?.xpubHashId)
        let pendingSwaps = try? await BoltzController.shared.gets(with: pendingSwapsIds ?? [])
        let swapTask: ((_ swap: BoltzSwap) async -> Void?) = { [self] swap in
            await self.completePendingSwap(swap, accountName: account?.name ?? "")
        }
        await withTaskGroup(of: Void.self) { group in
            for swap in pendingSwaps ?? [] {
                group.addTask(priority: .background) {
                    await swapTask(swap)
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
    func accountsBy(_ assetId: String?) -> [WalletItem] {
        subaccounts.filter({ $0.satoshi?.keys.contains(assetId ?? $0.gdkNetwork.policyAsset ?? AssetInfo.btcId) ?? false })
    }
    func rotateBalanceDisplayMode() async throws {
        var isBTC = false
        if let session = self.session, let settings = session.settings {
            isBTC = settings.denomination == .BTC
        }
        balanceDisplayMode = balanceDisplayMode.next(isBTC)
        reloadBalances()
    }
    func relogin() async throws {
        let account = AccountsRepository.shared.current
        let credentials = try? await wm?.prominentSession?.getCredentials(password: "")
        let lightningCredentials = try? AuthenticationTypeHandler.getCredentials(method: .AuthKeyLightning, for: account?.keychainLightning ?? "")
        _ = try await wm?.login(credentials: credentials, lightningCredentials: lightningCredentials, device: wm?.hwDevice, masterXpub: nil, fullRestore: false, parentWalletId: nil)
        _ = try await wm?.subaccounts()
    }
}
