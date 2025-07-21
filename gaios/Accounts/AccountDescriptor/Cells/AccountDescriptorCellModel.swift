import Foundation
import UIKit
import gdk

struct AccountDescriptorCellModel {
    var account: WalletItem
    var descriptor: String {
        account.coreDescriptors?.joined(separator: "\n") ?? ""
    }
}
