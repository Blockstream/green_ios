import Foundation
import UIKit
import core


class AccountDescriptorViewModel {
    var account: Account
    var cardCellModels: [AlertCardCellModel] {
        return [AlertCardCellModel(type: AlertCardType.descriptorInfo)]
    }
    var descriptorCellModels: [AccountDescriptorCellModel] {
        return [AccountDescriptorCellModel(account: account)]
    }
    init(account: Account) {
        self.account = account
    }
}
