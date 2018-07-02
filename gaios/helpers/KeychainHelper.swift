//
//  KeyChainHelper.swift
//  gaios
//
//  Created by Strahinja Markovic on 6/19/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Security
import Foundation

class KeychainHelper {
    
    class func updatePassword(service: String, account: String, data: String) {
        guard let dataFromString = data.data(using: .utf8, allowLossyConversion: false) else {
            return
        }
        
        let status = SecItemUpdate(modifierQuery(service: service, account: account), [kSecValueData: dataFromString] as CFDictionary)
        
        checkError(status)
    }
    
    class func removePassword(service: String, account: String) {
        let status = SecItemDelete(modifierQuery(service: service, account: account))
        
        checkError(status)
    }
    
    class func savePassword(service: String, account: String, data: String) {
        guard let dataFromString = data.data(using: .utf8, allowLossyConversion: false) else {
            return
        }
        
        let keychainQuery: [CFString: Any] = [kSecClass: kSecClassGenericPassword,
                                              kSecAttrService: service,
                                              kSecAttrAccount: account,
                                              kSecValueData: dataFromString]
        
        let status = SecItemAdd(keychainQuery as CFDictionary, nil)
        
        checkError(status)
    }
    
    class func loadPassword(service: String, account: String) -> String? {
        var dataTypeRef: CFTypeRef?
        
        let status = SecItemCopyMatching(modifierQuery(service: service, account: account), &dataTypeRef)
        
        if status == errSecSuccess,
            let retrievedData = dataTypeRef as? Data {
            return String(data: retrievedData, encoding: .utf8)
        } else {
            checkError(status)
            
            return nil
        }
    }
    
    fileprivate static func modifierQuery(service: String, account: String) -> CFDictionary {
        let keychainQuery: [CFString: Any] = [kSecClass: kSecClassGenericPassword,
                                              kSecAttrService: service,
                                              kSecAttrAccount: account,
                                              kSecReturnData: kCFBooleanTrue]
        
        return keychainQuery as CFDictionary
    }
    
    fileprivate static func checkError(_ status: OSStatus) {
        if status != errSecSuccess {
            if #available(iOS 11.3, *),
                let err = SecCopyErrorMessageString(status, nil) {
                print("Operation failed: \(err)")
            } else {
                print("Operation failed: \(status). Check the error message through https://osstatus.com.")
            }
        }
    }
}
