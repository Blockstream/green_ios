//
//  AccountStore.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/4/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import PromiseKit

class AccountStore {

    static let shared = AccountStore()
    var m_wallets:Array<WalletItem> = Array()

    public func fetchWallets() -> Array<WalletItem> {
        var result = Array<WalletItem>()
        let loginData = getGAService().loginData

        let subacounts:NSArray = loginData!["subaccounts"] as! NSArray
        do {
            let mainAddress = try getSession().getReceiveAddress()
            let json = try getSession().getBalance(numConfs: 1)
            let balance:String = json!["satoshi"] as! String
            let mainWallet:WalletItem = WalletItem(name: "Main Wallet", address: mainAddress, balance: balance, currency: "USD")
            result.append(mainWallet)
            for element in subacounts{
                let account = (element as? [String: Any])!
                let address = account["receiving_id"] as! String
                let satoshi = account["satoshi"] as! String
                let name = account["name"] as! String
                let currency = account["fiat_currency"] as! String
                let wallet: WalletItem = WalletItem(name: name, address: address, balance: satoshi, currency: currency)
                result.append(wallet)
            }
        } catch {
            print("something went wrong trying to get subbacounts")
        }
        m_wallets = result
        return result
    }

    private init() { }
    
    func getWallets() -> Promise<Array<WalletItem>> {
        return wrap {self.fetchWallets()}
    }
}



class WalletItem {
    var name: String
    var address: String
    var balance: String
    var currency: String

    init(name: String, address: String, balance: String, currency: String) {
        self.name = name
        self.address = address
        self.balance = balance
        self.currency = currency
    }
}
