import Foundation
@preconcurrency import core
import greenaddress
@preconcurrency import gdk

struct WalletState: Sendable {
    var subaccounts: [WalletItem] = WalletManager.current?.visibleSubaccounts ?? []
    var balances: [String: Int64]?
    var totals: (String, Int64)?
    var assetAmountList: AssetAmountList?
    var priceCache: PriceChartModel?
    var txsGdk: [String: [Transactions]]?
    var currentPage = 0
    var txsMeld: [Transaction] = []
    var txs: [Transaction]?
    var txsCanLoadMore: Bool = true
    var remoteAlerts: [RemoteAlert]?
    var alertCards: [AlertCardType] = []
    var backupCards: [AlertCardType] = []
    var promos: [PromoCellModel] = []
    var balanceDisplayMode = BalanceDisplayMode.denom
    var settings: [SettingSection] = []
    var security: [SecuritySection] = []
    var nestedTxs: [String: [String: [Transaction]]] = [:]

    var hideBalance = UserDefaults.standard.bool(forKey: AppStorageConstants.hideBalance.rawValue) {
        didSet {
            UserDefaults.standard.set(hideBalance, forKey: AppStorageConstants.hideBalance.rawValue)
        }
    }
}
