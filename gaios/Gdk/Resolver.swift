import Foundation
import UIKit
import core
import gdk
import hw

public class CodeAlertController: UIAlertController {

    var willDisappearBlock: ((UIAlertController) -> Void)?
    var didDisappearBlock: ((UIAlertController) -> Void)?

    public override func viewWillDisappear(_ animated: Bool) {
        willDisappearBlock?(self)
        super.viewWillDisappear(animated)
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if self.textFields?.first?.text?.count == 6 {
            didDisappearBlock?(self)
        }
    }
}

class HwPopupResolver: HwInterfaceResolver {

    func showMasterBlindingKeyRequest() async {
        DispatchQueue.main.async {
            let storyboard = UIStoryboard(name: "Utility", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "MasterKeyViewController") as? MasterKeyViewController {
                vc.modalPresentationStyle = .overFullScreen
                UIApplication.topViewController()?.present(vc, animated: false, completion: nil)
            }
        }
    }

    func dismiss() async {
        DispatchQueue.main.async {
            UIApplication.topViewController()?.dismiss(animated: true)
        }
    }
}

public class PopupResolver: NSObject, UITextFieldDelegate, PopupResolverDelegate {

    private var textContinuation: CheckedContinuation<String, Error>?

    public func code(_ method: String, attemptsRemaining: Int?, enable2faCallMethod: Bool, network: NetworkSecurityCase, failure: Bool) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            textContinuation = continuation
            codeCustomDialog(method, attemptsRemaining: attemptsRemaining, enable2faCallMethod: enable2faCallMethod, network: network, failure: failure)
        }
    }

    public func codeCustomDialog(_ method: String, attemptsRemaining: Int?, enable2faCallMethod: Bool, network: NetworkSecurityCase, failure: Bool) {
        let methodDesc: String
        var methodEnum: TwoFactorType?
        if method == TwoFactorType.email.rawValue {
            methodDesc = "id_email"
            methodEnum = .email
        } else if method == TwoFactorType.phone.rawValue {
            methodDesc = "id_phone_call"
            methodEnum = .phone
        } else if method == TwoFactorType.sms.rawValue {
            methodDesc = "id_sms"
            methodEnum = .sms
        } else {
            methodDesc = "id_authenticator_app"
            methodEnum = .gauth
        }

        let twoFAFlow = UIStoryboard(name: "TwoFAFlow", bundle: nil)
        guard let vc = twoFAFlow.instantiateViewController(withIdentifier: "TwoFactorAuthViewController") as? TwoFactorAuthViewController else { return }

        vc.methodEnum = methodEnum
        vc.commontitle = String(format: "id_please_provide_your_1s_code".localized, methodDesc.localized)
        vc.attemptsRemaining = attemptsRemaining
        vc.enable2faCallMethod = enable2faCallMethod
        vc.failure = failure

        vc.onCancel = { [weak self] in
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.resolve2faOff()
            }
            self?.textContinuation?.resume(throwing: TwoFactorCallError.cancel(localizedDescription: "id_action_canceled"))
        }

        vc.onCode = { [weak self] code in
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.resolve2faOff()
            }
            self?.textContinuation?.resume(returning: code)
        }
        vc.onEnable2faCall = { [weak self] in
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.resolve2faOff()
            }
            self?.textContinuation?.resume(throwing: TwoFactorCallError.cancel(localizedDescription: ""))

            DispatchQueue.main.async {
                let storyboard = UIStoryboard(name: "AuthenticatorFactors", bundle: nil)
                if let vc = storyboard.instantiateViewController(withIdentifier: "SetPhoneViewController") as? SetPhoneViewController {
                    vc.phoneCall = true
                    vc.network = network
                    vc.isSmsBackup = true
                    if let controller = UIApplication.topViewController() as? WalletTabBarViewController {
                        controller.navigationController?.pushViewController(vc, animated: true)
                    }
                }
            }
        }
        DispatchQueue.main.async {
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.resolve2faOn(vc)
            }
        }
    }

    public func method(_ methods: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            textContinuation = continuation
            methodCustomDialog(methods)
        }
    }
    public func methodCustomDialog(_ methods: [String]) {

        let twoFAFlow = UIStoryboard(name: "TwoFAFlow", bundle: nil)
        guard let vc = twoFAFlow.instantiateViewController(withIdentifier: "TwoFAMethodViewController") as? TwoFAMethodViewController else { return }

        vc.methods = methods

        vc.onCancel = { [weak self] in
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.resolve2faOff()
            }
            self?.textContinuation?.resume(throwing: TwoFactorCallError.cancel(localizedDescription: "id_action_canceled"))
        }

        vc.onType = { [weak self] tfType in
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.resolve2faOff()
            }
            self?.textContinuation?.resume(returning: tfType.rawValue)
        }

        DispatchQueue.main.async {
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.resolve2faOn(vc)
            }
        }
    }

    public func textFieldDidChangeSelection(_ textField: UITextField) {
        DispatchQueue.main.async {
            if textField.text?.count == 6 {
                UIApplication.topViewController()?.dismiss(animated: true)
            }
        }
    }
}
