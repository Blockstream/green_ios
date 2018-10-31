
import Foundation
import UIKit

protocol TwoFactorCallDelegate: class {
    func onResolve(_ sender: TwoFactorCallHelper)
    func onRequest(_ sender: TwoFactorCallHelper)
    func onDone(_ sender: TwoFactorCallHelper)
    func onError(_ sender: TwoFactorCallHelper, text: String)
}

class TwoFactorCallHelper {
    var caller: TwoFactorCall
    var delegate: TwoFactorCallDelegate?

    init(_ caller: TwoFactorCall) {
        self.caller = caller
    }
    func resolve() throws {
        let json = try caller.getStatus()
        let status = json!["status"] as! String
        print( status )
        if (status == "call") {
            try caller.call()
            try resolve()
        } else if(status == "done") {
            delegate?.onDone(self)
        } else if (status == "error") {
            let error = json!["error"] as! String
            delegate?.onError(self, text: error)
        } else if(status == "resolve_code") {
            delegate?.onResolve(self)
        } else if(status == "request_code") {
            let methods = json!["methods"] as! NSArray
            if(methods.count > 1) {
                delegate?.onResolve(self)
            } else {
                let method = methods[0] as! String
                try caller.requestCode(method: method)
                try resolve()
            }
        }
    }

    static func CodePopup(_ sender: TwoFactorCallHelper) -> UIAlertController {
        let alert = UIAlertDefaultStyleController(title: "Insert Code", message: "Insert two factor code")
        alert.addTextField { (textField) in
            textField.text = ""
            textField.textColor = UIColor.white
            textField.tintColor = UIColor.customTitaniumDark()
            textField.borderColor = UIColor.customTitaniumLight()
            textField.backgroundColor = UIColor.customTitaniumDark()
        }
        alert.addAction(UIAlertAction(title: "CANCEL", style: .cancel, handler: { [weak alert] (_) in
            sender.delegate?.onError(sender, text: "")
            alert?.dismiss(animated: true, completion: nil)
        }))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] (_) in
            let textField = alert!.textFields![0]
            print("Text field: \(textField.text)")
            do {
                try sender.caller.resolveCode(code: textField.text)
                try sender.resolve()
            } catch {
                sender.delegate?.onError(sender, text: "")
            }
        }))
        return alert
    }

    static func MethodPopup(_ sender: TwoFactorCallHelper) -> UIAlertController {
        let alert = UIAlertDefaultStyleController(title: "Selector", message: "Select two factor method")
        let json = try! sender.caller.getStatus()
        let methods = json!["methods"] as! NSArray
        for index in 0..<methods.count {
            let method = methods[index] as! String
            alert.addAction(UIAlertAction(title: method, style: .default, handler: { (action) in
                do {
                    try sender.caller.requestCode(method: method)
                    try sender.resolve()
                } catch {
                    sender.delegate?.onError(sender, text: "")
                }

            }))
        }
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

class TransactionHelper {
    // Common variable
    public var data: [String: Any]

    enum GDKError: Error {
        case AddressFormatError(String)
    }

    // Constructors
    init(_ data: [String: Any]) throws {
        self.data = try getSession().createTransaction(details: data)!
    }

    init(_ uri: String) throws {
        var details = [String: Any]()
        var toAddress = [String: Any]()
        toAddress["address"] = uri
        details["addressees"] = [toAddress]
        self.data = try getSession().createTransaction(details: details)!
        let error = self.data["error"] as! String
        if (error == "id_invalid_address") {
            throw GDKError.AddressFormatError(error)
        }
    }

    func addresses() -> Array<[String : Any]> {
        var addresses = Array<[String : Any]>()
        if (self.data["addressees"] is NSArray) {
            let addrNSArray = self.data["addressees"] as! NSArray
            for i in 0...addrNSArray.count-1 {
                let obj = addrNSArray[i] as! NSDictionary
                addresses.append((obj as? [String : Any])!)
            }
            return addresses
        } else {
            return self.data["addressees"] as! Array<[String : Any]>
        }
    }
}
