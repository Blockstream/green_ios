
import Foundation
import UIKit
import PromiseKit

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
                    if methods.count > 1 {
                        try PopupMethodResolver(sender)
                            .method(methods)
                            .then { method in
                                return try! self.requestCode(method: method)
                            }.wait()
                    } else {
                        try! self.requestCode(method: methods[0])
                    }
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
                seal.fulfill(json)
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
