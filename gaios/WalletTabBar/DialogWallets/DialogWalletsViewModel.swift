import Foundation
import UIKit
import gdk
import core

class DialogWalletsViewModel {
    var title = "Wallets".localized
    var accounts: [Account]

    init(accounts: [Account]) {
        self.accounts = accounts
    }
}
