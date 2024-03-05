import Foundation
import UIKit
import gdk

enum LTShortcutAction {
    case addFromAccount
    case addFromCreate
    case remove
}

class LTShortcutViewModel {

    var account: Account

    var action: LTShortcutAction

    var title: String {
        
        switch action {
        case .addFromAccount, .addFromCreate:
            return "Lightning Account Shortcut Activated".localized
        case .remove:
            return "Lightning Account Shortcut Removed".localized
        }
    }
    var hint: String {

        let l1 = "With this shortcut you'll enjoy:".localized
        let l2 = "Direct access to the Lightning account, keep the rest of your funds safe and separate while on the go".localized
        let l3 = "Quick biometrics login".localized
        let l4 = "Seamless lightning payments receiving, no need to keep your app open".localized
        let pad = "\n\n• "
        let hint = l1 + pad + l2 + pad + l3 + pad + l4

        switch action {
        case .addFromAccount, .addFromCreate:
            return hint
        case .remove:
            return "You can always turn this on when you need.".localized
        }
    }
    var btnMore: String {
        return "Learn More".localized
    }
    var btnMain: String {
        switch action {
        case .addFromAccount, .addFromCreate:
            return "Ok, I understand".localized
        case .remove:
            return "id_ok".localized
        }
    }
    var btnLater: String {
        return "Maybe later".localized
    }
    var btnCancel: String {
        if account.isJade && action == .addFromCreate {
            return "No, I'll repeat the setup".localized
        }
        return "id_cancel".localized
    }
    var linkMore: String {
        return "https://help.blockstream.com/hc/en-us/articles/23020279153177"
    }
    init(account: Account, action: LTShortcutAction) {
        self.action = action
        self.account = account
    }
}
