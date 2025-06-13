import Foundation
import UIKit
import hw

enum GenuineCheckEndState {
    case progress
    case cancel
    case genuine
    case notGenuine
    case exit
}
class GenuineCheckEndViewModel {

    let BleHwManager: BleHwManager
    var state: GenuineCheckEndState
    var error: Error? = nil

    init(BleHwManager: BleHwManager) {
        self.BleHwManager = BleHwManager
        self.state = .progress
    }

    var icon: UIImage {
        switch state {
        case .notGenuine:
            return UIImage(named: "ic_genuine_check_state_warn")!
        case .genuine:
            return UIImage(named: "ic_genuine_check_state_genuine")!
        case .cancel:
            return UIImage(named: "ic_genuine_check_state_not_genuine")!
        case .progress:
            return UIImage()
        case .exit:
            return UIImage()
        }
    }
    var title: String {
        switch state {
        case .cancel:
            return "id_genuine_check_canceled".localized
        case .genuine:
            return "id_your_jade_is_genuine".localized
        case .notGenuine:
            return "id_this_jade_is_not_genuine".localized
        case .progress:
            return "id_authenticate_your_jade".localized
        case .exit:
            return "id_error".localized
        }
    }
    var hint: String {
        switch state {
        case .cancel:
            return "id_we_were_unable_to_complete_the".localized
        case .genuine:
            return "id_your_jade_plus_has_been".localized
        case .notGenuine:
            return "id_this_device_was_not".localized
        case .progress:
            return "id_perform_a_genuine_check_to".localized
        case .exit:
            return ""
        }
    }
    var btnDIY: String {
        return "id_continue_as_diy".localized
    }
    var btnSupport: String {
        return "id_contact_support".localized
    }
    var btnContinue: String {
        return "id_continue_with_jade".localized
    }
    var btnCancel: String {
        return "id_skip".localized
    }
    var btnRetry: String {
        return "id_try_again".localized
    }
    var lblInfo: String {
        return "id_confirm_on_your_device".localized
    }

    func run() async {
        do {
            let validated = try await BleHwManager.jade?.genuineCheck()
            state = validated ?? false ? .genuine : .notGenuine
        } catch {
            self.error = error
            switch error {
            case HWError.Declined(_):
                state = .cancel
            case HWError.Abort(_):
                state = .notGenuine
            default:
                state = .exit
            }
        }
    }
}
