import Foundation
import UIKit
import core

struct AccountDescriptorCellModel {
    var account: WalletItem
    var descriptor: String {
        account.coreDescriptors?.joined(separator: "\n") ?? ""
    }
}
