import Foundation
import UIKit
import gdk

class DialogAccountsViewModel {

    var seetInfo: AssetInfo?
    var accountCellModels: [AccountCellModel]
    var hideBalance: Bool

    init(assetInfo: AssetInfo?, accountCellModels: [AccountCellModel], hideBalance: Bool) {
        self.accountCellModels = accountCellModels
        self.hideBalance = hideBalance
        self.seetInfo = assetInfo
    }
}
