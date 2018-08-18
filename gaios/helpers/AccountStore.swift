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
    var exchangeRate: Double = 0 //usd for 100000000
    var feeEstimatelow: Int = 0
    var feeEstimateMedium: Int = 0
    var feeEstimateHigh: Int = 0
    var mainAddress:String = ""

    public func fetchWallets() -> Array<WalletItem> {
        var result = Array<WalletItem>()
        let loginData = getGAService().loginData

        let subacounts:NSArray = loginData!["subaccounts"] as! NSArray
        do {
            if(mainAddress == "") {
                mainAddress = try getSession().getReceiveAddress(subaccount: 0)
            }
            let json = try getSession().getBalance(subaccount: 0, numConfs: 1)
            let balance:String = json!["satoshi"] as! String
            let mainWallet:WalletItem = WalletItem(name: "Main Wallet", address: mainAddress, balance: balance, currency: "USD", pointer: 0)
            result.append(mainWallet)
            for element in subacounts{
                let account = (element as? [String: Any])!
                let address = account["receiving_id"] as! String
                let satoshi = account["satoshi"] as! String
                let name = account["name"] as! String
                let pointer = account["pointer"] as! UInt32
                let currency = account["fiat_currency"] as! String
                let wallet: WalletItem = WalletItem(name: name, address: address, balance: satoshi, currency: currency, pointer: pointer)
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

    func dateFromTimestamp(date: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.date(from: date)!
    }

    func satoshiToUSD(amount: Int) -> Double {
        let result: Double = (Double(amount) * exchangeRate) / 100000000
        return result
    }

    func btcToUSD(amount: Double) ->Double {
        return satoshiToUSD(amount: Int(amount * 100000000))
    }

    func USDtoSatoshi(amount: Double) -> Int {
        let result: Int = Int(amount / exchangeRate) * 100000000
        return result
    }

    func USDtoBTC(amount: Double) -> Double{
        let result: Double = amount / exchangeRate
        return result
    }

    func initializeAccountStore() {
        guard let login = getGAService().loginData else {
            return
        }

        if let exch:String = login["fiat_exchange"] as? String{
            exchangeRate = Double(exch)!
        }

        if let fee:[String:Any] = login["fee_estimates"] as? [String:Any] {
            let lowPriority = fee["12"] as! [String : Any]
            if let lowPriorityFee = lowPriority["feerate"] as? String {
                feeEstimatelow = Int((Double(lowPriorityFee)! * 100000000) / 1000) //satoshi per byte
            }
            let mediumPriority = fee["6"] as! [String : Any]
            if let mediumPriorityFee = mediumPriority["feerate"] as? String {
                feeEstimateMedium = Int((Double(mediumPriorityFee)! * 100000000) / 1000) //satoshi per byte
            }
            let highPriority = fee["2"] as! [String : Any]
            if let highPriorityFee = highPriority["feerate"] as? String {
                feeEstimateHigh = Int((Double(highPriorityFee)! * 100000000) / 1000) //satoshi per byte
            }
            print(lowPriority)
        }
        NotificationStore.shared.initializeNotificationStore()

        print(exchangeRate)
    }
}

class WalletItem {
    var name: String
    var address: String
    var balance: String
    var currency: String
    var pointer: UInt32

    init(name: String, address: String, balance: String, currency: String, pointer: UInt32) {
        self.name = name
        self.address = address
        self.balance = balance
        self.currency = currency
        self.pointer = pointer
    }
}
