import UIKit

import core
import Foundation

class TabTransactVM: TabViewModel {
    var txs: [Transaction]? {
        state.txs
    }
    var hideBalance: Bool {
        state.hideBalance
    }
    var subaccounts: [Account]? {
        state.subaccounts
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
    var alertCards: [AlertCardType] {
        state.alertCards
    }
    var backupCards: [AlertCardType] {
        state.backupCards
    }
    var balanceDisplayMode: BalanceDisplayMode {
        state.balanceDisplayMode
    }
    var defaultCurrency: String? {
        if let settings = wm.settings {
            return settings.pricing["currency"]
        }
        return nil
    }
    var currentPage: Int {
        get { state.currentPage }
        set { state.currentPage = newValue }
    }
    var txsCanLoadMore: Bool {
        state.txsCanLoadMore
    }
    func rotateBalanceDisplayMode() async {
        try? await walletDataModel.rotateBalanceDisplayMode()
    }
    func hideBalance(_ value: Bool) async throws {
        try await walletDataModel.hideBalance(value)
    }
}

extension TabTransactVM: TransactActionsDataSource {}
