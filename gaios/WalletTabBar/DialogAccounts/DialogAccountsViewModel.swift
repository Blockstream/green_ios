import Foundation
import UIKit
import gdk

class DialogAccountsViewModel {

    var title: String
    var hint: String
    var isSelectable: Bool
    var seetInfo: AssetInfo?
    var accountCellModels: [AccountCellModel]
    var hideBalance: Bool

    init(title: String,
         hint: String,
         isSelectable: Bool,
         assetInfo: AssetInfo?,
         accountCellModels: [AccountCellModel],
         hideBalance: Bool) {
        self.title = title
        self.hint = hint
        self.isSelectable = isSelectable
        self.accountCellModels = accountCellModels
        self.hideBalance = hideBalance
        self.seetInfo = assetInfo
    }
}
