import Foundation
import UIKit
import core
import gdk

class AccountDescriptorViewModel {
    var account: WalletItem
    var cardCellModels: [AlertCardCellModel] {
        return [AlertCardCellModel(type: AlertCardType.descriptorInfo)]
    }
    var descriptorCellModels: [AccountDescriptorCellModel] {
        return [AccountDescriptorCellModel(account: account)]
    }
    init(account: WalletItem) {
        self.account = account
    }
}
