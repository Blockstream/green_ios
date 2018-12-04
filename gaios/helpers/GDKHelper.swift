
import Foundation
import UIKit
import PromiseKit

protocol TwoFactorCallDelegate: class {
    func onResolve(_ sender: TwoFactorCallHelper?)
    func onRequest(_ sender: TwoFactorCallHelper?)
    func onDone(_ sender: TwoFactorCallHelper?)
    func onError(_ sender: TwoFactorCallHelper?, text: String)
}

class TwoFactorCallHelper {
    var caller: TwoFactorCall
    var delegate: TwoFactorCallDelegate?

    init(_ caller: TwoFactorCall) {
        self.caller = caller
    }

    init(_ caller: TwoFactorCall, delegate: TwoFactorCallDelegate) {
        self.caller = caller
        self.delegate = delegate
    }

    func resolve() throws {
        // should be called in a not ui/main thread
        let json = try caller.getStatus()
        let status = json!["status"] as! String
        print( status )
        if (status == "call") {
            try caller.call()
            try resolve()
        } else if(status == "done") {
            DispatchQueue.main.async {
                self.delegate?.onDone(self)
            }
        } else if (status == "error") {
            let error = json!["error"] as! String
            DispatchQueue.main.async {
                self.delegate?.onError(self, text: error)
            }
        } else if(status == "resolve_code") {
            DispatchQueue.main.async {
                self.delegate?.onResolve(self)
            }
        } else if(status == "request_code") {
            let methods = json!["methods"] as! NSArray
            if(methods.count > 1) {
                DispatchQueue.main.async {
                    self.delegate?.onRequest(self)
                }
            } else {
                let method = methods[0] as! String
                try caller.requestCode(method: method)
                try resolve()
            }
        }
    }

    static func CodePopup(_ sender: TwoFactorCallHelper) -> UIAlertController {
        let json = try! sender.caller.getStatus()
        let method = json!["method"] as! String
        let alert = UIAlertDefaultStyleController(title: "Please provide your \(method) code", message: "")
        // set input text
        alert.addTextField { (textField) in
            textField.text = ""
            textField.textColor = UIColor.white
            textField.tintColor = UIColor.customTitaniumDark()
            textField.borderColor = UIColor.customTitaniumLight()
            textField.backgroundColor = UIColor.customTitaniumDark()
            textField.keyboardType = .numberPad
        }
        // set actions with style
        alert.addAction(UIAlertAction(title: "CANCEL", style: .cancel, handler: { [weak alert] (_) in
            sender.delegate?.onError(sender, text: "")
            alert?.dismiss(animated: true, completion: nil)
        }))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] (_) in
            let textField = alert!.textFields![0]
            print("Text field: \(textField.text)")
            // Perform action on separate thread
            DispatchQueue.global(qos: .default).async {
                do {
                    try sender.caller.resolveCode(code: textField.text)
                    try sender.resolve()
                } catch {
                    DispatchQueue.main.async {
                        sender.delegate?.onError(sender, text: "")
                    }
                }
            }
        }))
        return alert
    }

    static func MethodPopup(_ sender: TwoFactorCallHelper) -> UIAlertController {
        let alert = UIAlertDefaultStyleController(title: "Choose Two-Factor Authentication method", message: "")
        let json = try! sender.caller.getStatus()
        let methods = json!["methods"] as! NSArray
        for index in 0..<methods.count {
            let method = methods[index] as! String
            alert.addAction(UIAlertAction(title: method, style: .default, handler: { (action) in
                // Perform action on separate thread
                DispatchQueue.global(qos: .default).async {
                    do {
                        try sender.caller.requestCode(method: method)
                        try sender.resolve()
                    } catch {
                        DispatchQueue.main.async {
                            sender.delegate?.onError(sender, text: "")
                        }
                    }
                }
            }))
        }
        // set cancel action
        alert.addAction(UIAlertAction(title: "CANCEL", style: .cancel, handler: { [weak alert] (_) in
            sender.delegate?.onError(sender, text: "")
            alert?.dismiss(animated: true, completion: nil)
        }))
        return alert
    }

    static func UIAlertDefaultStyleController(title: String, message: String) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let subview = (alert.view.subviews.first?.subviews.first?.subviews.first!)! as UIView
        subview.backgroundColor = UIColor.black
        subview.tintColor = UIColor.white
        alert.view.backgroundColor = UIColor.black
        alert.view.tintColor = UIColor.white
        alert.view.borderColor = UIColor.darkGray
        alert.view.borderWidth = CGFloat(1.0)

        let attributedTitle = NSAttributedString(string: title, attributes: [ NSAttributedStringKey.foregroundColor : UIColor.white ])
        let attributedMessage = NSAttributedString(string: message, attributes: [ NSAttributedStringKey.foregroundColor : UIColor.lightGray ])
        alert.setValue(attributedTitle, forKey: "attributedTitle")
        alert.setValue(attributedMessage, forKey: "attributedMessage")
        return alert;
    }
}

extension TwoFactorCall {
    func resolve(_ sender: UIViewController) throws -> Promise<[String:Any]?> {
        return Promise<[String:Any]?> { seal in
            var status = ""
            var json: [String:Any] = [:]
            while status != "error" && status != "done" {
                json = try self.getStatus()!
                status = json["status"] as! String
                if status == "call" {
                    try self.call().wait()
                } else if status == "request_code" {
                    let methods: [String] = json["methods"] as! [String]
                    try PopupMethodResolver(sender)
                        .method(methods)
                        .then { method in
                            return try! self.requestCode(method: method)
                        }.wait()
                } else if status == "resolve_code" {
                    let method: String = json["method"] as! String
                    try PopupCodeResolver(sender)
                        .code(method)
                        .then { code in
                            return try! self.resolveCode(code: code)
                        }.wait()
                }
            }
            // Return a promise
            if status == "done" {
                if (json["result"] is NSNull) {
                    seal.fulfill(nil)
                } else if (json["result"] is NSArray) {
                    let result: [String:Any]? = json["result"] as! [String:Any]?
                    seal.fulfill(result)
                }
            } else if status == "error"{
                //let result: String = json["error"] as! String
                seal.reject(GaError.GenericError)
            }
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
            let alert = UIAlertController(title: "Please provide your \(method) code", message: "", preferredStyle: .alert)
            alert.addTextField { (textField) in
                textField.placeholder = "code"
                textField.keyboardType = .numberPad
            }
            alert.addAction(UIAlertAction(title: "CANCEL", style: .cancel) { (action: UIAlertAction) in
                result.reject(GaError.GenericError)
            })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { (action: UIAlertAction) in
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
            let alert = UIAlertController(title: "Choose Two-Factor Authentication method", message: "", preferredStyle: .alert)
            methods.forEach { (method: String) in
                alert.addAction(UIAlertAction(title: method, style: .default) { (action: UIAlertAction) in
                    result.fulfill(method)
                })
            }
            alert.addAction(UIAlertAction(title: "CANCEL", style: .cancel) { (action: UIAlertAction) in
                result.reject(GaError.GenericError)
            })
            DispatchQueue.main.async {
                self.viewController.present(alert, animated: true, completion: nil)
            }
        }
    }
}
