import Foundation
import UIKit
import gdk
import greenaddress
import hw
import core
import AsyncAlgorithms

class ManageAssetViewModel {

    let walletDataModel: WalletDataModel
    let wallet: WalletManager
    var mainAccount: Account
    var assetId: String
    var selectedSubaccount: WalletItem?

    var state = WalletState()
    var onUpdate: ((RefreshFeature?) -> Void)?
    var observationTask: Task<Void, Never>?
    var notificationTask: Task<Void, Never>?

    var subaccounts: [WalletItem] {
        if assetId == AssetInfo.lightningId {
            return state.subaccounts.filter { $0.networkType.lightning }
        } else if assetId == AssetInfo.btcId || assetId == AssetInfo.testId {
            return state.subaccounts.filter { $0.networkType.bitcoin }
        } else if assetId == AssetInfo.lbtcId || assetId == AssetInfo.ltestId {
            return state.subaccounts.filter { $0.networkType.liquid }
        } else {
            return state.subaccounts.filter { $0.networkType.liquid && $0.hasAsset(assetId) }
        }
    }
    var balances: [String: Int64]? {
        state.balances
    }
    var totals: (String, Int64)? {
        state.totals
    }
    var assetAmountList: AssetAmountList? {
        state.assetAmountList
    }
    var txs: [Transaction]? {
        if let selectedSubaccount {
            return state.nestedTxs[selectedSubaccount.id]?[assetId]
        }
        return nil
    }
    var actions: [ActionCardType] {
        if assetId == AssetInfo.lightningId && hasOnchainFunds() {
            return [.lightningTransfer]
        }
        return []
    }

    init(walletDataModel: WalletDataModel, wallet: WalletManager, mainAccount: Account, assetId: String, selectedSubaccount: WalletItem?) {
        self.walletDataModel = walletDataModel
        self.wallet = wallet
        self.mainAccount = mainAccount
        self.assetId = assetId
        self.selectedSubaccount = selectedSubaccount
        observationTask = Task { await self.startObserving() }
        notificationTask = Task { await self.subscribeNotifications() }
    }

    private func startObserving() async {
        // Subscribe to the Actor's multi-subscriber AsyncStream which now yields
        // `WalletDataModel.SubscriberUpdate` (state + optional single RefreshFeature).
        for await update in await walletDataModel.states() {
            self.state = update.state
            self.onUpdate?(update.feature)
        }
    }

    func refresh() {
        Task {
            if let selectedSubaccount {
                await walletDataModel.triggerRefresh(features: [.balance, .nestedTxs(subaccount: selectedSubaccount.id, assetId: assetId)])
            } else {
                await walletDataModel.triggerRefresh(features: [.subaccounts, .balance])
            }
        }
    }

    deinit {
        observationTask?.cancel()
        notificationTask?.cancel()
    }

    private func subscribeNotifications() async {
        logger.info("ManageAssetViewModel subscribeNotifications")
        let stream = wallet.addNotificationSubscriber()
        for await notification in stream {
            switch notification {
            case .newBlock(blockheight: let blockheight):
                logger.info("ManageAssetViewModel newBlock")
                refresh()
            case .newTransaction(transaction: let transaction):
                logger.info("ManageAssetViewModel newTransaction")
                refresh()
            case .reconnected:
                logger.info("ManageAssetViewModel reconnected")
                refresh()
            default:
                break
            }
        }
    }
    var hideBalance: Bool {
        get {
            return UserDefaults.standard.bool(forKey: AppStorageConstants.hideBalance.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: AppStorageConstants.hideBalance.rawValue)
        }
    }
    func renameSubaccount(name: String) async throws {
        guard let selectedSubaccount else { return }
        let params = UpdateSubaccountParams(subaccount: selectedSubaccount.pointer, name: name)
        try await selectedSubaccount.session?.renameSubaccount(params)
        if let subaccount = try await wallet.subaccountUpdate(account: selectedSubaccount) {
            self.selectedSubaccount = subaccount
        }
    }
    func archiveSubaccount() async throws {
        guard let selectedSubaccount else { return }
        let params = UpdateSubaccountParams(subaccount: selectedSubaccount.pointer, hidden: true)
        try await selectedSubaccount.session?.updateSubaccount(params)
        if let subaccount = try await wallet.subaccountUpdate(account: selectedSubaccount) {
            self.selectedSubaccount = subaccount
        }
        _ = try await wallet.subaccounts()
    }
    var isFunded: Bool? {
        if let selectedSubaccount {
            if selectedSubaccount.satoshi == nil { return false }
            if let sats = selectedSubaccount.satoshi?[assetId] {
                return sats > 0
            }
        }
        return nil
    }
    func hasLightning() -> Bool {
        guard let account = AccountsRepository.shared.current else {
            return false
        }
        return AuthenticationTypeHandler.findAuth(
            method: .AuthKeyLightning,
            forNetwork: account.keychainLightning)
    }

    func canSendLightning() -> Bool {
        return (wallet.lightningSession?.nodeState?.channelsBalanceSatoshi ?? 0) > 0
    }
    func hasOnchainFunds() -> Bool {
        return (wallet.lightningSession?.nodeState?.onchainBalanceSatoshi ?? 0) > 0
    }
    func currency() -> String? {
        wallet.prominentSession?.settings?.pricing["currency"]
    }
}
