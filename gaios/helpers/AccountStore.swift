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

    let denominationBTC: Double = 100000000
    let denominationMilliBTC: Double = 100000
    let denominationMicroBTC: Double = 100

    public func fetchWallets() -> Array<WalletItem> {
        var result = Array<WalletItem>()
        do {
            let json = try getSession().getSubaccounts()
            let subacounts = json!["array"] as! NSArray
            for element in subacounts{
                let account = (element as? [String: Any])!
                let address = account["receiving_id"] as! String
                let pointer = account["pointer"] as! UInt32
                let balance = try getSession().getBalance(subaccount: pointer, numConfs: 1)
                let satoshi = balance!["satoshi"] as! String
                let name = pointer == 0 ? "Main Wallet" : account["name"] as! String
                let currency = balance!["fiat_currency"] as! String
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

    func getDenomination() -> Double  {
        let denomination = SettingsStore.shared.getDenominationSettings()
        if (denomination == SettingsStore.shared.denominationPrimary) {
            return denominationBTC
        } else if (denomination == SettingsStore.shared.denominationMilli) {
            return denominationMilliBTC
        } else if (denomination == SettingsStore.shared.denominationMicro) {
            return denominationMicroBTC
        }
        return denominationBTC
    }

    func dateFromTimestamp(date: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.date(from: date)!
    }

    func satoshiToUSD(amount: Int) -> Double {
        let result: Double = (Double(amount) * exchangeRate) / getDenomination()
        return result
    }

    func btcToUSD(amount: Double) ->Double {
        return satoshiToUSD(amount: Int(amount * getDenomination()))
    }

    func USDtoSatoshi(amount: Double) -> Int {
        let result = (amount / exchangeRate) * getDenomination()
        return Int(result)
    }

    func USDtoBTC(amount: Double) -> Double{
        let result: Double = amount / exchangeRate
        return result
    }

    func initializeAccountStore() {
        SettingsStore.shared.initSettingsStore()
        exchangeRate = 1 //get exchange rate
        NotificationStore.shared.initializeNotificationStore()
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
