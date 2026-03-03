import Foundation
import AsyncAlgorithms

import core
import greenaddress
@preconcurrency import gdk

actor WalletDataModel {

    // Singleton
    let wallet: WalletManager
    var mainAccount: Account

    // Private
    private var state = WalletState()

    // Channels
    private var subscribers: [UUID: AsyncStream<SubscriberUpdate>.Continuation] = [:]
    private var notificationTask: Task<Void, Error>?

    init(wallet: WalletManager, mainAccount: Account) {
        self.wallet = wallet
        self.mainAccount = mainAccount
        notificationTask = Task { await self.subscribeNotifications() }
    }

    // Async Multi-Subscriber Stream
    func states() -> AsyncStream<SubscriberUpdate> {
        let id = UUID()
        return AsyncStream { continuation in
            Task { await self.addSubscriber(id: id, continuation: continuation) }
        }
    }

    // Helper to register a subscriber from actor context
    private func addSubscriber(id: UUID, continuation: AsyncStream<SubscriberUpdate>.Continuation) async {
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(id: id) }
        }
        subscribers[id] = continuation
        // send the current state immediately with no event
        continuation.yield(SubscriberUpdate(state: state, feature: nil))
    }

    private func removeSubscriber(id: UUID) {
        subscribers.removeValue(forKey: id)
    }

    // Trigger a refresh event on features
    func triggerRefresh(features: Set<RefreshFeature>) async {
        await withTaskGroup(of: Void.self) { [weak self] group in
            for feature in features {
                group.addTask { await self?.performFetch(feature: feature) }
            }
        }
    }

    private func subscribeNotifications() async {
        logger.info("WalletDataModel subscribeNotifications")
        let stream = wallet.addNotificationSubscriber()
        for await notification in stream {
            switch notification {
            case .newBlock:
                logger.info("WalletDataModel newBlock")
                // Update content if exist an unconfirmed tx
                let btcBlockHeight = wallet.bitcoinBlockHeight()
                let liquidBlockHeight = wallet.liquidBlockHeight()
                let pendings = state.txs?.filter { $0.confirmations(block: ($0.isLiquid ? liquidBlockHeight ?? 0: btcBlockHeight ?? 0)) <= ($0.isLiquid ? 2 : 6) }
                if pendings?.count ?? 0 > 0 {
                    await performFetchBalance()
                    await performFetchTransactions(reset: true)
                }
            case .newSubaccount:
                logger.info("WalletDataModel newSubaccount")
                //await performFetchSubaccounts(refresh: false)
                //await performFetchBalance()
                //await performFetchTransactions(reset: true)
            case .newTransaction:
                logger.info("WalletDataModel newTransaction")
                await performFetchBalance()
                await performFetchTransactions(reset: true)
            case .twoFactorReset:
                logger.info("WalletDataModel twoFactorReset")
                await performFetchSubaccounts(refresh: false)
                await performSettings()
            case .updateSettings:
                logger.info("WalletDataModel updateSettings")
                await performFetchSubaccounts(refresh: false)
                await performSettings()
            case .disconnected:
                logger.info("WalletDataModel disconnected")
            case .reconnected:
                logger.info("WalletDataModel reconnect")
                await performFetchBalance()
                await performFetchTransactions(reset: true)
            case .tor:
                break
            case .refreshAssets:
                await performFetchBalance()
            case .invoicePaid:
                await performFetchBalance()
                await performFetchTransactions(reset: true)
            case .paymentSucceed:
                await performFetchBalance()
                await performFetchTransactions(reset: true)
            case .paymentFailed:
                break
            }
        }
    }

    private func performFetchBalance() async {
        do {
            let subaccounts = state.subaccounts
            let balances = try await wallet.balances(subaccounts: subaccounts)
            let totals = balances.filter { AssetInfo.baseIds.contains($0.0) }.map { $0.1 }.reduce(0, { (res, partial) in res + partial })
            let assetAmountList = AssetAmountList(balances)
            await update(.balance) {
                $0.balances = balances
                $0.totals = ("btc", totals)
                $0.assetAmountList = assetAmountList
            }
        } catch {
            logger.error("WalletDataModel performFetchBalance error: \(error.localizedDescription)")
        }
    }
    private func performFetchSubaccounts(refresh: Bool) async {
        do {
            let subaccounts = try await wallet.visibleSubaccounts(refresh)
            await update(.subaccounts) { $0.subaccounts = subaccounts }
        } catch {
            logger.error("WalletDataModel performFetchSubaccounts error: \(error.localizedDescription)")
        }
    }
    private func performFetchTransactions(reset: Bool) async {
        do {
            let subaccounts = state.subaccounts
            let txsGdk = try await fetchGdkTransactions(subaccounts: subaccounts, page: reset ? 0 : state.currentPage, reset: reset, previous: [:])
            let prominentSubaccounts = try? await wallet.prominentSession?.subaccounts().filter({ !$0.hidden })
            let txsMeld = try? await fetchMeldTransactions(prominentSubaccounts?.first)
            let list = txsGdk
                .flatMap({$0.value})
                .flatMap({$0.list})
            let txs = Array(list + (txsMeld ?? []))
            let filtered = txs
                .sorted(by: >)
                .prefix((state.currentPage + 1) * 30)
            logger.info("WalletDataModel 1tx: \(filtered.first?.hash ?? "")")
            await update(.txs(reset: reset)) {
                $0.txsGdk = txsGdk
                $0.txsCanLoadMore = txsGdk.count > 0
                $0.txsMeld = txsMeld ?? []
                $0.txs = (reset ? [] : ($0.txs ?? [])) + Array(filtered)
                $0.currentPage += 1
            }
        } catch {
            logger.error("WalletDataModel performFetchTransactions error: \(error.localizedDescription)")
        }
    }
    private func performFetchNestedTransactions(subaccount: String, assetId: String) async {
        do {
            let subaccounts = state.subaccounts.filter { $0.id == subaccount }
            let txsGdk = try await fetchGdkAllTransactions(subaccounts: subaccounts)
            let txsMeld = try? await fetchMeldTransactions(subaccounts.first)
            let txs = Array(txsGdk + (txsMeld ?? []))
                .filter({ AssetInfo.baseIds.contains(assetId) || $0.amounts.keys.contains(assetId) })
                .sorted(by: >)
            await update(.nestedTxs(subaccount: subaccount, assetId: assetId)) {
                if $0.nestedTxs.keys.contains(subaccount) {
                    $0.nestedTxs[subaccount]?[assetId] = txs
                } else {
                    $0.nestedTxs[subaccount] = [assetId: txs]
                }
            }
        } catch {
            logger.error("WalletDataModel performFetchNestedTransactions error: \(error.localizedDescription)")
        }
    }

    var defaultCurrency: String? {
        if let settings = wallet.prominentSession?.settings {
            return settings.pricing["currency"]
        }
        return nil
    }

    private func performFetchPriceChart() async {
        do {
            let currency = defaultCurrency ?? "USD"
            do {
                try await Api.shared.fetch(currency: currency.lowercased())
                await update(.priceChart) { $0.priceCache = Api.shared.priceCache }
            } catch {
                try await Api.shared.fetch(currency: "USD".lowercased())
                await update(.priceChart) { $0.priceCache = Api.shared.priceCache }
            }
        } catch {
            logger.error("WalletDataModel performFetchPriceChart error: \(error.localizedDescription)")
        }
    }
    private func performAlertCards() async {
        let (alertCards, remoteAlerts) = await fetchAlertCards()
        await update(.alertCards) {
            $0.remoteAlerts = remoteAlerts
            $0.alertCards = alertCards
        }
    }
    private func performPromos() async {
        let promos = await fetchPromoCards()
        await update(.promos) { $0.promos = promos }
    }
    private func performSettings() async {
        let settings = await fetchSettings()
        await update(.settings) { $0.settings = settings }
    }

    private func performSecurity() async {
        let security = await fetchSecurity()
        await update(.security) { $0.security = security }
    }

    private func performFetch(feature: RefreshFeature) async {
        switch feature {
        case .subaccounts:
            await performFetchSubaccounts(refresh: false)
            await performFetchBalance()
        case .balance:
            await performFetchBalance()
        case .txs(reset: let reset):
            await performFetchTransactions(reset: reset)
        case .priceChart:
            await performFetchPriceChart()
        case .discover:
            await performFetchSubaccounts(refresh: true)
            await performFetchBalance()
            await performFetchTransactions(reset: true)
            await performSettings()
            await performSecurity()
        case .alertCards:
            await performAlertCards()
        case .promos:
            await performPromos()
        case .settings:
            await performSettings()
        case .security:
            await performSecurity()
        case .nestedTxs(subaccount: let subaccount, assetId: let assetId):
            await performFetchNestedTransactions(subaccount: subaccount, assetId: assetId)
        }
    }

    func fetchGdkAllTransactions(subaccounts: [WalletItem]) async throws -> [Transaction] {
        // get gdk/lightning transactions
        let txs = try await wallet.allTransactions(subaccounts: subaccounts)
        return txs
    }

    func fetchGdkTransactions(subaccounts: [WalletItem], page: Int, reset: Bool, previous: [String: [Transactions]]) async throws -> [String: [Transactions]] {
        // get gdk/lightning transactions
        let txs = try await wallet.pagedTransactions(subaccounts: subaccounts, of: reset ? 0 : page)
        var cache = reset ? [:] : previous
        for (account, pagetxs) in txs {
            cache[account] = (cache[account] ?? []) + [pagetxs]
        }
        return cache
    }

    func fetchMeldTransactions(_ subaccount: WalletItem?) async throws -> [Transaction]? {
        guard let subaccount, let xpubHashId = mainAccount.xpubHashId else {
            return nil
        }
        if !Meld.needFetchingTxs(xpub: xpubHashId) {
            return nil
        }
        let meld = Meld()
        let meldTxs = try await meld.getPendingTransactions(xpub: xpubHashId)
        Meld.enableFetchingTxs(xpub: xpubHashId, enable: !meldTxs.isEmpty)
        return meldTxs.map({ Transaction($0.details, subaccountId: subaccount.id) })
    }

    func fetchAlertCards() async -> ([AlertCardType], [RemoteAlert]?) {
        var cards: [AlertCardType] = []
        if mainAccount.isEphemeral {
            // Bip39 ephemeral wallet
            cards.append(.ephemeralWallet)
        }
        if mainAccount.gdkNetwork.mainnet == false {
            // Testnet wallet
            cards.append(AlertCardType.testnetNoValue)
        }
        // countly alerts
        var remoteAlerts = state.remoteAlerts
        if remoteAlerts == nil {
            remoteAlerts = RemoteAlertManager.shared.alerts(screen: .walletOverview, networks: wallet.activeNetworks)
        }
        if let remoteAlert = remoteAlerts?.first {
            cards.append(AlertCardType.remoteAlert(remoteAlert))
        }
        // Failure login session
        cards += await wallet.failureSessionsError.errors
            .filter {
                switch $0.value {
                case TwoFactorCallError.failure(localizedDescription: let txt):
                    return txt != "id_login_failed"
                default:
                    return true
                }
            }.map { AlertCardType.login($0.key, $0.value) }
        // Load dispute on not wo session
        if !mainAccount.isWatchonly {
            wallet.sessions.values.forEach { session in
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
        }
        // Load missing princing
        if Balance.fromSatoshi(0, assetId: wallet.prominentSession?.gdkNetwork.getFeeAsset() ?? "btc")?.toFiat().0 == "n/a" {
            cards.append(AlertCardType.fiatMissing)
        }
        // Load system messages
        let messages = try? await wallet.loadSystemMessages()
        messages?.forEach { msg in
            if !msg.text.isEmpty {
                cards.append(AlertCardType.systemMessage(msg))
            }
        }
        // Load lightning errors
        if let lightningSession = wallet.lightningSession {
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
        let expired = try? await wallet.getExpiredSubaccounts()
        if let expired = expired, !expired.isEmpty && !mainAccount.isWatchonly {
            cards.append(.reEnable2fa)
        }
        return (cards, remoteAlerts)
    }
    func fetchPromoCards() async -> [PromoCellModel] {
        if let promo = PromoManager.shared.promoCellModels(.homeTab).first?.promo,
           let source = PromoManager.shared.promoCellModels(.homeTab).first?.source {
            PromoManager.shared.promoView(promo: promo, source: source)
        }
        return state.subaccounts.count == 0 ? [] : PromoManager.shared.promoCellModels(.homeTab)
    }
    func fetchSettings() async -> [SettingSection] {
        if mainAccount.isWatchonly {
            return [
                .init(section: .header, items: [.header]),
                .init(section: .wallet, items: [.rename, .unifiedDenominationExchange, .autoLogout, .logout]),
                .init(section: .about, items: [.version, .supportID, .support])
            ]
        }
        var walletItems: [SettingsItem] = [.rename, .unifiedDenominationExchange, .autoLogout, .logout]
        if wallet.isEphemeral {
            walletItems.removeAll(where: { $0 == .rename })
        }
        var accountItems: [SettingsItem] = []
        if !wallet.isEphemeral && AppSettings.shared.experimental {
            accountItems += [.lightning]
        }
        accountItems += [.ampID]
        if wallet.hasMultisig {
            accountItems += [.twoFactorAuthication, .pgpKey]
        }
        accountItems += [.watchOnly, .archievedAccounts, .createAccount]
        if !wallet.isEphemeral && mainAccount.isHW && !mainAccount.isWatchonly {
            accountItems += [.swaps]
        }
        return [
            .init(section: .header, items: [.header]),
            .init(section: .wallet, items: walletItems),
            .init(section: .account, items: accountItems),
            .init(section: .about, items: [.version, .supportID, .support])
        ]
    }

    func fetchSecurity() async -> [SecuritySection] {
        let isWatchonly = mainAccount.isWatchonly
        let isHW = mainAccount.isHW
        var security: [SecuritySection] = [.init(section: .header, items: [.header])]
        if !isWatchonly {
            security += [.init(section: .level, items: [.header])]
        } else {
            security += [.init(section: .watchonly, items: [.header])]
        }
        if BackupHelper.shared.needsBackup(walletId: mainAccount.id) && BackupHelper.shared.isDismissed(walletId: mainAccount.id, position: .securityTab) == false {
            security += [.init(section: .backup, items: [.header])]
        }
        if !isWatchonly && !isHW {
            security += [.init(section: .unlock, items: [.bio, .pin])]
        }
        if mainAccount.isHW {
            let boardType = mainAccount.boardType ?? BleHwManager.shared.jade?.version?.boardType
            switch boardType {
            case .some(.v2):
                security += [.init(section: .jade, items: [.genuineCheck, .fwUpdate])]
            default:
                security += [.init(section: .jade, items: [.fwUpdate])]
            }
        }
        if !isWatchonly && !isHW {
            security += [.init(section: .recovery, items: [.recoveryPhrase])]
        }
        return security
    }

    // Notify all subscribers with the updated state
    private func update(_ feature: RefreshFeature? = nil, _ mutate: (inout WalletState) -> Void) async {
        mutate(&state)
        for cont in subscribers.values {
            cont.yield(SubscriberUpdate(state: state, feature: feature))
        }
    }

    func rotateBalanceDisplayMode() async throws {
        let nextState = state.balanceDisplayMode.next()
        await update(.balance) { $0.balanceDisplayMode = nextState }
    }
    func hideBalance(_ value: Bool) async throws {
        await update(.balance) { $0.hideBalance = value }
    }

    // finish all active continuations
    func shutdown() {
        logger.info("WalletDataModel shutdown")
        for cont in subscribers.values {
            cont.finish()
        }
        notificationTask?.cancel()
        subscribers.removeAll()
    }
}
