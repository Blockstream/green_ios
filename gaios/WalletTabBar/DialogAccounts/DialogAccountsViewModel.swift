import Foundation
import UIKit

import core

class DialogAccountsViewModel {

    var title: String
    var hint: String
    var isSelectable: Bool
    var assetId: String?
    var accounts: [Account]
    var hideBalance: Bool

    init(title: String,
         hint: String,
         isSelectable: Bool,
         assetId: String?,
         accounts: [Account],
         hideBalance: Bool) {
        self.title = title
        self.hint = hint
        self.isSelectable = isSelectable
        self.accounts = accounts
        self.hideBalance = hideBalance
        self.assetId = assetId
    }

    var accountCellModels: [AccountCellModel] {
        var list = [AccountCellModel]()
        for account in accounts {
            let assets = WalletManager.current?.accountBackendOrNil(account)?.assets
            let satohi = assetId == nil ? nil : assets?[assetId!]
            list += [
                AccountCellModel(
                    account: account,
                    satoshi: satohi ?? 0,
                    assetId: assetId)]
        }
        return list
    }
}
