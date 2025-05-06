import Foundation
import UIKit
import gdk
import core

class DialogAccountsViewModel {

    var title: String
    var hint: String
    var isSelectable: Bool
    var assetId: String?
    var accounts: [WalletItem]
    var hideBalance: Bool

    init(title: String,
         hint: String,
         isSelectable: Bool,
         assetId: String?,
         accounts: [WalletItem],
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
            let satohi = assetId == nil ? nil : account.satoshi?[assetId!]
            list += [
                AccountCellModel(
                    account: account,
                    satoshi: satohi,
                    assetId: assetId)]
        }
        return list
    }
}
