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
        switch action {
        case .addFromAccount, .addFromCreate:
            return "Quickly and directly access your Lightning Account for enhanced privacy, while keeping the bulk of your funds safe and separate while you're on the go.\n\nPlus, enjoy receiving payments seamlessly! No need to keep the app open or constantly monitor your phone.\n\nYou won’t need to enter your PIN to access your funds on lightning via this shortcut.".localized
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
