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
            return "Lightning Account Shortcut".localized
        case .remove:
            return "Lightning Account Shortcut Removed".localized
        }
    }
    var hint: String {
        switch action {
        case .addFromAccount:
            return "Quickly access your Lightning account separate from your primary wallet, to maintain security and privacy of any other account in your wallet.\n\n\nYou won’t need to enter your PIN to access your funds on lightning via this shortcut.".localized
        case .addFromCreate:
            return "Want to quickly access your Lightning account separate from your primary wallet, to maintain security and privacy of any other account in your wallet.\n\n\nYou won’t need to enter your PIN to access your funds on lightning via this shortcut.".localized
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
            return "Yes, create a shortcut".localized
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
