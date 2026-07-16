import Foundation
import AsyncAlgorithms

import core
import greenaddress

actor WalletDataModel {

    // Singleton
    let wm: WalletManager
    var mainWallet: Wallet

    // Private
    private var state = WalletState()
    private var isFetchingBalance = false
    private var isFetchingTransactions = false

    // Channels
    private var subscribers: [UUID: AsyncStream<SubscriberUpdate>.Continuation] = [:]
    private var eventSubscribers: [UUID: AsyncStream<EventNotificationTypes>.Continuation] = [:]

    init(wm: WalletManager, mainWallet: Wallet) {
        self.wm = wm
        self.mainWallet = mainWallet
        wm.newNotificationDelegate = self
    }

    // Async Multi-Subscriber Stream in actor-isolated
    func states() -> AsyncStream<SubscriberUpdate> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<SubscriberUpdate>.makeStream()
        subscribers[id] = continuation
        continuation.onTermination = { @Sendable [weak self] _ in
            Task { await self?.removeSubscriber(id: id) }
        }
        continuation.yield(SubscriberUpdate(state: state, feature: nil))
        return stream
    }

    func events() -> AsyncStream<EventNotificationTypes> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<EventNotificationTypes>.makeStream()
        eventSubscribers[id] = continuation

        // This guarantees no memory leaks. When the ViewModel cancels its Task,
        // this termination block cleans up the dictionary entry.
        continuation.onTermination = { @Sendable [weak self] _ in
            Task { await self?.removeEventSubscriber(id: id) }
        }
        return stream
    }

    private func removeSubscriber(id: UUID) {
        subscribers[id]?.finish()
        subscribers.removeValue(forKey: id)
    }

    private func removeEventSubscriber(id: UUID) {
        eventSubscribers[id]?.finish()
        eventSubscribers.removeValue(forKey: id)
    }

    // Trigger a refresh event on features
    func triggerRefresh(features: Set<RefreshFeature>) async {
        await withTaskGroup(of: Void.self) { [weak self] group in
            for feature in features {
                group.addTask { await self?.performFetch(feature: feature) }
            }
        }
    }

    // TODO: isFetchingBalance is a temp guard; the real fix is making WalletManager an actor
    private func performFetchBalance() async {
        if isFetchingBalance { return }
        isFetchingBalance = true
        defer { isFetchingBalance = false }
        do {
            logger.info("WalletDataModel performFetchBalance")
            let subaccounts = state.subaccounts
            if subaccounts.isEmpty { return }
            let balancesForSubaccount = try await wm.balances(subaccounts: subaccounts)
            let balances = balancesForSubaccount
                .flatMap { $0.value }
                .reduce([String: Int64]()) { (dict, tuple) in
                    var nextDict = dict
                    let prevValue = dict[tuple.key] ?? 0
                    nextDict.updateValue(prevValue + tuple.value, forKey: tuple.key)
                    return nextDict
                }
            let totals = balances.filter { AssetInfo.baseIds.contains($0.0) }.map { $0.1 }.reduce(0, { (res, partial) in res + partial })
            let assetAmountList = balances.toList()
            await update(.balance) {
                $0.balancesForSubaccount = balancesForSubaccount
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
            let subaccounts = try await wm.getAccounts(refresh: refresh)
            await update(.subaccounts) { $0.subaccounts = subaccounts.sorted() }
        } catch {
            logger.error("WalletDataModel performFetchSubaccounts error: \(error.localizedDescription)")
        }
    }
    private func performFetchTransactions(reset: Bool) async {
        if isFetchingTransactions || (!reset && !state.txsCanLoadMore) {
            return
        }
        isFetchingTransactions = true
        defer { isFetchingTransactions = false }
        do {
            logger.info("WalletDataModel performFetchTransactions")
            let subaccounts = state.subaccounts
            let currentPage = reset ? 0 : state.currentPage
            let txsCurrentPage = try await wm.pagedTransactions(subaccounts: subaccounts, of: currentPage)
            let loadMore = !txsCurrentPage.values.flatMap { $0.list }.isEmpty
            var cache = reset ? [:] : state.txsGdk ?? [:]
            for (account, pagetxs) in txsCurrentPage {
                cache[account] = (cache[account] ?? []) + [pagetxs]
            }
            let prominentSubaccount = subaccounts.filter({ !$0.hidden }).first
            let txsMeld = try? await fetchMeldTransactions(prominentSubaccount)
            var list = cache
                .flatMap({$0.value})
                .flatMap({$0.list})
            list = Array(list + (txsMeld ?? []))
            list = list.sorted(by: >)
            if loadMore {
                list = Array(list.prefix((currentPage + 1) * 30))
            }
            await update(.txs(reset: reset)) {
                $0.txsGdk = cache
                $0.txsCanLoadMore = loadMore
                $0.txsMeld = txsMeld ?? []
                $0.txs = list
                $0.currentPage = currentPage + 1
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
        if let settings = wm.prominentSession?.settings {
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

    func fetchGdkAllTransactions(subaccounts: [Account]) async throws -> [Transaction] {
        // get gdk/lightning transactions
        let txs = try await wm.allTransactions(subaccounts: subaccounts)
        return txs
    }

    func fetchGdkTransactions(subaccounts: [Account], page: Int, reset: Bool, previous: [String: [Transactions]]) async throws -> [String: [Transactions]] {
        // get gdk/lightning transactions
                let txs = try await wm.pagedTransactions(subaccounts: subaccounts, of: reset ? 0 : page)
                var cache = reset ? [:] : previous
                for (account, pagetxs) in txs {
                    cache[account] = (cache[account] ?? []) + [pagetxs]
                }
        return cache
    }

    func fetchMeldTransactions(_ subaccount: Account?) async throws -> [Transaction]? {
        guard let subaccount, let xpubHashId = mainWallet.xpubHashId else {
            return nil
        }
        if !Meld.needFetchingTxs(xpub: xpubHashId) {
            return nil
        }
        let meld = Meld()
        let meldTxs = try await meld.getPendingTransactions(xpub: xpubHashId)
        Meld.enableFetchingTxs(xpub: xpubHashId, enable: !meldTxs.isEmpty)
        return meldTxs.map({ Transaction($0.details, accountId: subaccount.id) })
    }

    func fetchAlertCards() async -> ([AlertCardType], [RemoteAlert]?) {
        var cards: [AlertCardType] = []
        if mainWallet.isEphemeral {
            // Bip39 ephemeral wallet
            cards.append(.ephemeralWallet)
        }
        if mainWallet.gdkNetwork.mainnet == false {
            // Testnet wallet
            cards.append(AlertCardType.testnetNoValue)
        }
        // countly alerts
        var remoteAlerts = state.remoteAlerts
        if remoteAlerts == nil {
            remoteAlerts = RemoteAlertManager.shared
                .alerts(
                    screen: .walletOverview,
                    networks: Array(wm.activeNetworkIds)
                )
        }
        if let remoteAlert = remoteAlerts?.first {
            cards.append(AlertCardType.remoteAlert(remoteAlert))
        }
        // Failure login session
        cards += wm.networkErrors
            .filter {
                switch $0.value {
                case TwoFactorCallError.failure(localizedDescription: let txt):
                    return txt != "id_login_failed"
                default:
                    return true
                }
            }.map { AlertCardType.login($0.key.network, $0.value) }
        // Load dispute on not wo session
        if !mainWallet.isWatchonly {
            wm.activeGdkMultisigBackends.map{$0.session}.forEach { session in
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
        if Balance.fromSatoshi(Int64(0), assetId: wm.prominentSession?.gdkNetwork.getFeeAsset() ?? "btc")?.toFiat().0 == "n/a" {
            cards.append(AlertCardType.fiatMissing)
        }
        // Load system messages
        let messages = try? await wm.getSystemMessages()
        messages?.forEach { msg in
            if !msg.text.isEmpty {
                cards.append(AlertCardType.systemMessage(msg))
            }
        }
        // Load expired 2fa utxos
        let expired = try? await wm.getExpiredSubaccounts()
        if let expired = expired, !expired.isEmpty && !mainWallet.isWatchonly {
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
        if mainWallet.isWatchonly {
            return [
                .init(section: .header, items: [.header]),
                .init(section: .wallet, items: [.rename, .unifiedDenominationExchange, .autoLogout, .logout]),
                .init(section: .about, items: [.version, .supportID, .support])
            ]
        }
        var walletItems: [SettingsItem] = [.rename, .unifiedDenominationExchange, .autoLogout, .logout]
        if wm.isEphemeral {
            walletItems.removeAll(where: { $0 == .rename })
        }
        var accountItems: [SettingsItem] = []
        if !wm.isEphemeral && mainWallet.boardType != .v2c && !mainWallet.isWatchonly {
            accountItems += [.lightning]
        }
        // AMP ID entry: AMP2 on software testnet; AMP0 (new sheet) elsewhere.
        // Watch-only wallets keep AMP hidden for this branch.
        if !mainWallet.isWatchonly {
            accountItems += [.ampID]
        }
        if wm.hasMultisig {
            accountItems += [.twoFactorAuthication, .pgpKey]
        }
        accountItems += [.watchOnly, .archievedAccounts, .createAccount]
        if !wm.isEphemeral && mainWallet.boardType != .v2c && !mainWallet.isWatchonly {
            accountItems += [.swaps]
        }
        if !wm.isEphemeral && !mainWallet.isWatchonly && mainWallet.hasBoltzKey {
            accountItems += [.rescanSwaps]
        }
        return [
            .init(section: .header, items: [.header]),
            .init(section: .wallet, items: walletItems),
            .init(section: .account, items: accountItems),
            .init(section: .about, items: [.version, .supportID, .support])
        ]
    }

    func fetchSecurity() async -> [SecuritySection] {
        let isWatchonly = mainWallet.isWatchonly
        let isHW = mainWallet.isHW
        var security: [SecuritySection] = [.init(section: .header, items: [.header])]
        if !isWatchonly {
            security += [.init(section: .level, items: [.header])]
        } else {
            security += [.init(section: .watchonly, items: [.header])]
        }
        if BackupHelper.shared.needsBackup(walletId: mainWallet.id) && BackupHelper.shared.isDismissed(walletId: mainWallet.id, position: .securityTab) == false {
            security += [.init(section: .backup, items: [.header])]
        }
        if !isWatchonly && !isHW {
            security += [.init(section: .unlock, items: [.bio, .pin])]
        }
        if mainWallet.isHW {
            let boardType = mainWallet.boardType ?? BleHwManager.shared.jade?.version?.boardType
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
        subscribers.removeAll()
        for cont in eventSubscribers.values {
            cont.finish()
        }
        eventSubscribers.removeAll()
    }
}

extension WalletDataModel: NewNotificationDelegate {
    nonisolated func didReceive(
        event: core.EventNotificationTypes,
        networkId: NetworkId
    ) {
        Task { await handleEvent(event) }
    }

    func handleEvent(_ event: core.EventNotificationTypes) async {
        for cont in eventSubscribers.values {
            cont.yield(event)
        }
        switch event {
        case .newBlock:
            logger.info("WalletDataModel newBlock")
            // Update content if exist an unconfirmed tx
            let btcBlockHeight = wm.bitcoinBlockHeight()
            let liquidBlockHeight = wm.liquidBlockHeight()
            //let pendings = state.txs?.filter {
            //    $0.confirmations(block: ($0.isLiquid ? liquidBlockHeight ?? 0: btcBlockHeight ?? 0)) <= (
            //            $0.isLiquid ? 2 : 6
            //        )
            //}
            //if pendings?.count ?? 0 > 0 {
                await triggerRefresh(features: [.balance, .txs(reset: true)])
            //}
        case .newSubaccount:
            logger.info("WalletDataModel newSubaccount")
        case .newTransaction:
            logger.info("WalletDataModel newTransaction")
            await triggerRefresh(features: [.balance, .txs(reset: true)])
        case .twoFactorReset:
            logger.info("WalletDataModel twoFactorReset")
            await triggerRefresh(features: [.subaccounts])
            await triggerRefresh(features: [.settings])
        case .updateSettings:
            logger.info("WalletDataModel updateSettings")
            await triggerRefresh(features: [.subaccounts])
            await triggerRefresh(features: [.settings])
        case .disconnected:
            logger.info("WalletDataModel disconnected")
        case .reconnected:
            logger.info("WalletDataModel reconnect")
            if !wm.isPaused() {
                await triggerRefresh(features: [.balance, .txs(reset: true)])
            }
        case .tor:
            break
        case .refreshAssets:
            logger.info("WalletDataModel refreshAssets")
            await triggerRefresh(features: [.subaccounts, .balance, .txs(reset: true)])
        case .invoicePaid:
            logger.info("WalletDataModel invoicePaid")
            await triggerRefresh(features: [.balance, .txs(reset: true)])
        case .paymentSucceed:
            logger.info("WalletDataModel paymentSucceed")
            await triggerRefresh(features: [.balance, .txs(reset: true)])
        case .paymentFailed:
            break
        }
    }
}
