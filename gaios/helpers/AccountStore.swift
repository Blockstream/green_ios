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

    public func fetchWallets() -> Array<WalletItem> {
        var result = Array<WalletItem>()
        let loginData = getGAService().loginData

        let subacounts:NSArray = loginData!["subaccounts"] as! NSArray
        do {
            let mainAddress = try getSession().getReceiveAddress()
            let json = try getSession().getBalance(numConfs: 1)
            let balance:String = json!["satoshi"] as! String
            let mainWallet:WalletItem = WalletItem(name: "Main Wallet", address: mainAddress, balance: balance, currency: "USD", pointer: 0)
            result.append(mainWallet)
            for element in subacounts{
                let account = (element as? [String: Any])!
                let address = account["receiving_id"] as! String
                let satoshi = account["satoshi"] as! String
                let name = account["name"] as! String
                let pointer = account["pointer"] as! Int
                let currency = account["fiat_currency"] as! String
                let wallet: WalletItem = WalletItem(name: name, address: address, balance: satoshi, currency: currency, pointer: pointer)
                result.append(wallet)
            }
        } catch {
            print("something went wrong trying to get subbacounts")
        }
        m_wallets = result
        getTransactions(wallets: result)
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

    func getTransactions(wallets: Array<WalletItem>) {
        for wallet in wallets {
            wrap{ try getSession().getTransactions(subaccount: wallet.pointer)
                }.done { (transactions:[Transaction]?) in
                    for tx in transactions ?? [] {
                        let json = try! tx.toJSON()!
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateStyle = .medium
                        dateFormatter.timeStyle = .short
                        let date = self.dateFromTimestamp(date: json["timestamp"] as! String)
                        let dateString = dateFormatter.string(from: date)
                        dateFormatter.dateFormat = "LLL"
                        let nameOfMonth = dateFormatter.string(from: date)
                        dateFormatter.dateFormat = "dd"
                        let nameOfDay = dateFormatter.string(from: date)
                        let val:String? = json["value_str"] as? String
                        let balance: Double? = Double(val!)
                        let toBtc: Double = balance! / 100000000
                        let formattedBalance: String = String(format: "%g BTC", toBtc)
                        let counterparty: String = json["counterparty"] as! String
                    }
            }
        }
    }

    func satoshiToUSD(amount: Int) -> Double {
        let result: Double = (Double(amount) * exchangeRate) / 100000000
        return result
    }

    func USDtoSatoshi(amount: Double) -> Int{
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
        print(exchangeRate)
    }
}

class WalletItem {
    var name: String
    var address: String
    var balance: String
    var currency: String
    var pointer: Int

    init(name: String, address: String, balance: String, currency: String, pointer: Int) {
        self.name = name
        self.address = address
        self.balance = balance
        self.currency = currency
        self.pointer = pointer
    }
}
