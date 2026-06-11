import Foundation
import UIKit
import core

struct AccountDescriptorCellModel {
    var account: Account
    var descriptor: String {
        account.coreDescriptors?.joined(separator: "\n") ?? ""
    }
}
