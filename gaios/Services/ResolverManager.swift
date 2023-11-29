import Foundation

import UIKit
import gdk
import greenaddress
import hw

class ResolverManager {
    
    let resolver: GDKResolver
    let session: SessionManager?
    
    init(
        _ factor: TwoFactorCall?,
        network: NetworkSecurityCase,
        connected: @escaping() -> Bool = { true },
        hwDevice: HWProtocol?,
        session: SessionManager? = nil,
        bcurResolver: BcurResolver? = nil) {
        self.session = session
        resolver = GDKResolver(
            factor,
            gdkSession: session?.session,
            popupDelegate: PopupResolver(),
            hwDelegate: HWResolver(),
            bcurDelegate: bcurResolver,
            hwDevice: hwDevice,
            network: network,
            connected: connected
        )
    }

    func run() async throws -> [String: Any]? {
        let res = try await resolver.resolve()
        DispatchQueue.main.async {
            UIApplication.topViewController()?.stopAnimating()
        }
        return res
    }
}

class CodeAlertController: UIAlertController {

    var willDisappearBlock: ((UIAlertController) -> Void)?
    var didDisappearBlock: ((UIAlertController) -> Void)?

    override func viewWillDisappear(_ animated: Bool) {
        willDisappearBlock?(self)
        super.viewWillDisappear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if self.textFields?.first?.text?.count == 6 {
            didDisappearBlock?(self)
        }
    }
}

class PopupResolver: NSObject, UITextFieldDelegate, PopupResolverDelegate {
    
    private var textContinuation: CheckedContinuation<String, Error>?
    
    func code(_ method: String, attemptsRemaining: Int?, enable2faCallMethod: Bool, network: NetworkSecurityCase) async throws -> String {
        DispatchQueue.main.async {
            UIApplication.topViewController()?.stopAnimating()
        }
        return try await withCheckedThrowingContinuation { continuation in
            textContinuation = continuation
            codeCustomDialog(method, attemptsRemaining: attemptsRemaining, enable2faCallMethod: enable2faCallMethod, network: network)
        }
    }

    func codeCustomDialog(_ method: String, attemptsRemaining: Int?, enable2faCallMethod: Bool, network: NetworkSecurityCase) {
        let methodDesc: String
        if method == TwoFactorType.email.rawValue { methodDesc = "id_email" } else if method == TwoFactorType.phone.rawValue { methodDesc = "id_phone_call" } else if method == TwoFactorType.sms.rawValue { methodDesc = "id_sms" } else { methodDesc = "id_authenticator_app" }
        
        let twoFAFlow = UIStoryboard(name: "TwoFAFlow", bundle: nil)
        guard let vc = twoFAFlow.instantiateViewController(withIdentifier: "TwoFAViewController") as? TwoFAViewController else { return }
            
        vc.commontitle = String(format: NSLocalizedString("id_please_provide_your_1s_code", comment: ""), NSLocalizedString(methodDesc, comment: ""))
        vc.attemptsRemaining = attemptsRemaining ?? 3
        vc.enable2faCallMethod = enable2faCallMethod
        
        vc.onCancel = { [weak self] in
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate{
                appDelegate.resolve2faOff()
            }
            self?.textContinuation?.resume(throwing: TwoFactorCallError.cancel(localizedDescription: "id_action_canceled".localized))
        }
        
        vc.onCode = { [weak self] code in
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate{
                appDelegate.resolve2faOff()
            }
            self?.textContinuation?.resume(returning: code)
            DispatchQueue.main.async {
                UIApplication.topViewController()?.startAnimating()
            }
        }
        vc.onEnable2faCall = { [weak self] in
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate{
                appDelegate.resolve2faOff()
            }
            self?.textContinuation?.resume(throwing: TwoFactorCallError.cancel(localizedDescription: ""))

            DispatchQueue.main.async {
                let storyboard = UIStoryboard(name: "AuthenticatorFactors", bundle: nil)
                if let vc = storyboard.instantiateViewController(withIdentifier: "SetPhoneViewController") as? SetPhoneViewController {
                    vc.phoneCall = true
                    vc.network = network
                    vc.isSmsBackup = true

                    if let controller = UIApplication.topViewController() as? ContainerViewController {
                        if let nav = controller.nv.presentedViewController as? UINavigationController {
                            nav.pushViewController(vc, animated: true)
                        } else {
                            controller.nv.pushViewController(vc, animated: true)
                        }
                    }
                }
            }
        }
        DispatchQueue.main.async {
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate{
                appDelegate.resolve2faOn(vc)
            }
        }
    }

    func method(_ methods: [String]) async throws -> String {
        DispatchQueue.main.async {
            UIApplication.topViewController()?.stopAnimating()
        }
        return try await withCheckedThrowingContinuation { continuation in
            textContinuation = continuation
            methodCustomDialog(methods)
        }
    }
    func methodCustomDialog(_ methods: [String]) {

        let twoFAFlow = UIStoryboard(name: "TwoFAFlow", bundle: nil)
        guard let vc = twoFAFlow.instantiateViewController(withIdentifier: "TwoFAMethodViewController") as? TwoFAMethodViewController else { return }
            
        vc.methods = methods
        
        vc.onCancel = { [weak self] in
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate{
                appDelegate.resolve2faOff()
            }
            self?.textContinuation?.resume(throwing: TwoFactorCallError.cancel(localizedDescription: "id_action_canceled".localized))
        }
        
        vc.onType = { [weak self] tfType in
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate{
                appDelegate.resolve2faOff()
            }
            self?.textContinuation?.resume(returning: tfType.rawValue)
            DispatchQueue.main.async {
                UIApplication.topViewController()?.startAnimating()
            }
        }
        
        DispatchQueue.main.async {
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate{
                appDelegate.resolve2faOn(vc)
            }
        }
    }

    func textFieldDidChangeSelection(_ textField: UITextField) {
        DispatchQueue.main.async {
            if textField.text?.count == 6 {
                UIApplication.topViewController()?.dismiss(animated: true)
            }
        }
    }
}
