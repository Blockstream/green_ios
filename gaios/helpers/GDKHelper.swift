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
