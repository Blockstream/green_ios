
import Foundation
import UIKit
import PromiseKit

enum TwoFactorCallError : Error {
    case failure(localizedDescription: String)
    case cancel(localizedDescription: String)
}

extension TwoFactorCall {

    func resolve(_ sender: UIViewController) -> Promise<[String: Any]> {
        func step() -> Promise<[String: Any]> {
            return Guarantee().map{
                try self.getStatus()!
            }.then { json in
                try self.resolving(sender: sender, json: json).map { _ in json }
            }.then { json -> Promise<[String: Any]> in
                guard let status = json["status"] as? String else { throw GaError.GenericError }
                if status == "done" {
                    return Promise<[String: Any]> { seal in seal.fulfill(json) }
                } else {
                    return step()
                }
            }
        }
        return step()
    }

    func resolving(sender: UIViewController, json: [String: Any]) throws -> Promise<Void> {
        guard let status = json["status"] as? String else { throw GaError.GenericError }
        switch status {
        case "done":
            return Guarantee().asVoid()
        case "error":
            let error: String = json["error"] as! String
            throw TwoFactorCallError.failure(localizedDescription: NSLocalizedString(error, comment: ""))
        case "call":
            return try self.call()
        case "request_code":
            let methods: [String] = json["methods"] as! [String]
            if methods.count > 1 {
                return PopupMethodResolver(sender)
                    .method(methods)
                    .then { method in
                        return try self.requestCode(method: method)
                    }
            } else {
                return try self.requestCode(method: methods[0])
            }
        case "resolve_code":
            let method: String = json["method"] as! String
            return PopupCodeResolver(sender)
                .code(method)
                .then { code in
                    return try self.resolveCode(code: code)
                }
        default:
            return Guarantee().asVoid()
        }
    }
}

class PopupCodeResolver {
    private let viewController: UIViewController

    init(_ view: UIViewController) {
        self.viewController = view
    }

    func code(_ method: String) -> Promise<String> {
        return Promise { result in
            let methodDesc: String
            if method == TwoFactorType.email.rawValue { methodDesc = "id_email" }
            else if method == TwoFactorType.phone.rawValue { methodDesc = "id_phone_call" }
            else if method == TwoFactorType.sms.rawValue { methodDesc = "id_sms" }
            else { methodDesc = "id_google_authenticator" }
            let title = String(format: NSLocalizedString("id_please_provide_your_1s_code", comment: ""), NSLocalizedString(methodDesc, comment: ""))
            let alert = UIAlertController(title: title, message: "", preferredStyle: .alert)
            alert.addTextField { (textField) in
                textField.placeholder = ""
                textField.keyboardType = .numberPad
            }
            alert.addAction(UIAlertAction(title: NSLocalizedString("id_cancel", comment: ""), style: .cancel) { (action: UIAlertAction) in
                result.reject(TwoFactorCallError.cancel(localizedDescription: NSLocalizedString("id_action_canceled", comment: "")))
            })
            alert.addAction(UIAlertAction(title: NSLocalizedString("id_next", comment: ""), style: .default) { (action: UIAlertAction) in
                let textField = alert.textFields![0]
                result.fulfill(textField.text!)
            })
            DispatchQueue.main.async {
                self.viewController.present(alert, animated: true, completion: nil)
            }
        }
    }
}

class PopupMethodResolver {
    let viewController: UIViewController

    init(_ view: UIViewController) {
        self.viewController = view
    }

    func method(_ methods: [String]) -> Promise<String> {
        return Promise { result in
            let alert = UIAlertController(title: NSLocalizedString("id_choose_twofactor_authentication", comment: ""), message: "", preferredStyle: .alert)
            methods.forEach { (method: String) in
                let methodDesc: String
                if method == TwoFactorType.email.rawValue { methodDesc = "id_email" }
                else if method == TwoFactorType.phone.rawValue { methodDesc = "id_phone_call" }
                else if method == TwoFactorType.sms.rawValue { methodDesc = "id_sms" }
                else { methodDesc = "id_google_authenticator" }
                alert.addAction(UIAlertAction(title: NSLocalizedString(methodDesc, comment: ""), style: .default) { (action: UIAlertAction) in
                    result.fulfill(method)
                })
            }
            alert.addAction(UIAlertAction(title: NSLocalizedString("id_cancel", comment: ""), style: .cancel) { (action: UIAlertAction) in
                result.reject(TwoFactorCallError.cancel(localizedDescription: NSLocalizedString("id_action_canceled", comment: "")))
            })
            DispatchQueue.main.async {
                self.viewController.present(alert, animated: true, completion: nil)
            }
        }
    }
}
