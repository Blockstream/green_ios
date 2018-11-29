
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

enum TransactionError : Error {
    case invalid(localizedDescription: String)
}

struct Addressee : Codable {
    let address: String
    let satoshi: UInt64

    init(address: String, satoshi: UInt64) {
        self.address = address
        self.satoshi = satoshi
    }
}

protocol TransactionView {
    var addressees: [Addressee] { set get }
    var addresseesReadOnly: Bool { get }
    var error: String { get }
    var fee: UInt64 { get }
    var feeRate: UInt64 { set get }
    var isSweep: Bool { get }
    var memo: String { set get }
    var sendAll: Bool { set get }
    var transactionSize: UInt64 { get }
}

struct Transaction : TransactionView {
    var details: [String: Any]

    private func get<T>(_ key: String) -> T? {
        return details[key] as? T
    }

    init(_ details: [String: Any]) {
        self.details = details
    }

    var addressees: [Addressee] {
        get {
            let o: [[String: Any]] = get("addressees") ?? []
            return o.map { value in
                return Addressee(address: value["address"] as! String, satoshi: (value["satoshi"] as? UInt64) ?? 0)
            }
        }
        set {
            let addressees = newValue.map { addr -> [String: Any] in
                var o = [String: Any]()
                o["address"] = addr.address
                o["satoshi"] = addr.satoshi
                return o
            }
            details["addressees"] = addressees
        }
    }

    var addresseesReadOnly: Bool {
        get { return get("addresses_read_only") ?? false }
    }

    var error: String {
        get { return get("error") ?? String() }
    }

    var fee: UInt64 {
        get { return get("fee") ?? 0 }
    }

    var feeRate: UInt64 {
        get { return get("feeRate" ) ?? 0 }
        set { details["fee_rate"] = newValue }
    }

    var isSweep: Bool {
        get { return get("is_sweep") ?? false }
    }

    var memo: String {
        get { return get("memo") ?? String() }
        set { details["memo"] = newValue }
    }

    var sendAll: Bool {
        get { return get("send_all") ?? false }
        set { details["send_all"] = newValue }
    }

    var transactionSize: UInt64 {
        get { return get("transaction_vsize") ?? 0 }
    }
}

func createTransaction(details: [String: Any]) -> Promise<Transaction> {
    let bgq = DispatchQueue.global(qos: .background)
    return Guarantee().compactMap(on: bgq) {
        try getSession().createTransaction(details: details)
    }.map(on: bgq) { data in
        return Transaction(data)
    }
}

func signTransaction(details: [String: Any]) -> Promise<TwoFactorCall> {
    let bgq = DispatchQueue.global(qos: .background)
    return Guarantee().compactMap(on: bgq) {
        try getSession().signTransaction(details: details)
    }
}

func createTransaction(transaction: Transaction) -> Promise<Transaction> {
    return createTransaction(details: transaction.details)
}

func signTransaction(transaction: Transaction) -> Promise<TwoFactorCall> {
    return signTransaction(details: transaction.details)
}
