//
//  Transaction.swift
//  gaios
//
//  Created by luca on 31/10/2018.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation

protocol TwoFactorCallDelegate: class {
    func onResolve(_ sender: TwoFactorCallHelper)
    func onRequest(_ sender: TwoFactorCallHelper)
    func onDone(_ sender: TwoFactorCallHelper)
    func onError(_ sender: TwoFactorCallHelper, text: String)
}

class TwoFactorCallHelper : TwoFactorCall {
    var delegate: TwoFactorCallDelegate?
    
    func resolve() throws {
        let json = try self.getStatus()
        let status = json!["status"] as! String
        print( status )
        if (status == "call") {
            try self.call()
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
                try self.requestCode(method: method)
                try resolve()
            }
        }
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
