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
            return "Genuine check canceled".localized
        case .genuine:
            return "Your Jade is genuine!".localized
        case .notGenuine:
            return "This Jade is not genuine".localized
        case .progress:
            return "Authenticate your Jade".localized
        case .exit:
            return "id_error".localized
        }
    }
    var hint: String {
        switch state {
        case .cancel:
            return "We were unable to complete the genuine check because it was canceled on Jade.".localized
        case .genuine:
            return "We could successfully verify your Jade, enjoy the best Blockstream can offer you with your brand new jade.".localized
        case .notGenuine:
            return "This device was not manufactured by Blockstream. It could be DIY hardware or possibly a malicious clone. Please contact support for more assistance.".localized
        case .progress:
            return "Perform a genuine check to ensure that the Jade you received was manufactured by Blockstream.".localized
        case .exit:
            return ""
        }
    }
    var btnDIY: String {
        return "Continue as DIY".localized
    }
    var btnSupport: String {
        return "Contact Support".localized
    }
    var btnContinue: String {
        return "Continue with Jade".localized
    }
    var btnCancel: String {
        return "Skip".localized
    }
    var btnRetry: String {
        return "Retry".localized
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
