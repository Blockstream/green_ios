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
                let pointer = account["pointer"] as! UInt32
                let address = try getSession().getReceiveAddress(subaccount: pointer)
                let balance = try getSession().getBalance(subaccount: pointer, numConfs: 0)
                let satoshi = balance!["satoshi"] as! UInt32
                let name = pointer == 0 ? "Main Wallet" : account["name"] as! String
                let currency = balance!["fiat_currency"] as! String
                let wallet: WalletItem = WalletItem(name: name, address: address, balance: String(satoshi), currency: currency, pointer: pointer)
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

    func getFeeRateHigh() -> UInt64 {
        do {
            let json = try getSession().getFeeEstimates()
            let estimates = json!["estimates"] as! NSArray
            let result = estimates[2] as! UInt64
            return result
        } catch {
            print("something went wrong")
        }
        return 0
    }

    func getFeeRateMedium() -> UInt64 {
        do {
            let json = try getSession().getFeeEstimates()
            let estimates = json!["estimates"] as! NSArray
            let result = estimates[6] as! UInt64
            return result
        } catch {
            print("something went wrong")
        }
        return 0
    }

    func getFeeRateLow() -> UInt64 {
        do {
            let json = try getSession().getFeeEstimates()
            let estimates = json!["estimates"] as! NSArray
            let result = estimates[12] as! UInt64
            return result
        } catch {
            print("something went wrong")
        }
        return 0
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

    func satoshiToUSD(amount: UInt64) -> Double {
        let dict = ["satoshi" : amount]
        var amount: Double = 0
        do {
            let json = try getSession().convertAmount(input: dict)
            amount = Double(json!["fiat"] as! String)!
        } catch {
            print("something went wrong")
        }
        return amount
    }

    func btcToFiat(amount: Double) -> Double {
        let dict = ["btc" : String(amount)]
        var amount: Double = 0
        do {
            let json = try getSession().convertAmount(input: dict)
            amount = Double(json!["fiat"] as! String)!
        } catch {
            print("something went wrong")
        }

        return amount
    }

    func fiatToBtc(amount: Double) -> Double {
        let dict = ["fiat" : String(amount)]
        var amount: Double = 0
        do {
            let json = try getSession().convertAmount(input: dict)
            amount = Double(json!["btc"] as! String)!
        } catch {
            print("something went wrong")
        }

        return amount
    }

    func USDtoSatoshi(amount: Double) -> Int {
        let result = (amount / exchangeRate) * getDenomination()
        return Int(result)
    }

    func USDtoBTC(amount: Double) -> Double{
        let result: Double = amount / exchangeRate
        return result
    }

    func enableEmailTwoFactor(email: String) -> TwoFactorCall? {
        //nlohmann::json subconfig = { { "enabled", true }, { "confirmed", true }, { "data", data } };
        let dict = ["enabled": true, "confirmed": true, "data": email] as [String : Any]
        do {
            return try getSession().changeSettingsTwoFactor(method: "email", details: dict)
        } catch {
            print("couldn't change settings")
        }
        return nil
    }

    func enableSMSTwoFactor(phoneNumber: String) -> TwoFactorCall? {
        //nlohmann::json subconfig = { { "enabled", true }, { "confirmed", true }, { "data", data } };
        let dict = ["enabled": true, "confirmed": true, "data": phoneNumber] as [String : Any]
        do {
            return try getSession().changeSettingsTwoFactor(method: "sms", details: dict)
        } catch {
            print("couldn't change settings")
        }
        return nil
    }

    func enablePhoneCallTwoFactor(phoneNumber: String) -> TwoFactorCall? {
        let dict = ["enabled": true, "confirmed": true, "data": phoneNumber] as [String : Any]
        do {
            return try getSession().changeSettingsTwoFactor(method: "phone", details: dict)
        } catch {
            print("couldn't change settings")
        }
        return nil
    }

    func enableGauthTwoFactor() -> TwoFactorCall? {
        let config = getTwoFactorConfig()
        if (config == nil) {
            return nil
        }
        let gauth = config!["gauth"] as! [String: Any]
        let gauthdata = gauth["data"] as! String
        let dict = ["enabled": true, "confirmed": true, "data": gauthdata] as [String : Any]
        do {
            return try getSession().changeSettingsTwoFactor(method: "gauth", details: dict)
        } catch {
            print("couldn't change settings")
        }
        return nil
    }

    func getGauthSecret() -> String? {
        let config = getTwoFactorConfig()
        if (config == nil) {
            return nil
        }
        let gauth = config!["gauth"] as! [String: Any]
        let gauthdata = gauth["data"] as! String
        let url = URL(string: gauthdata)
        let secret = url?.queryItems["secret"]
        return secret
    }

    func getTwoFactorConfig() -> [String: Any]? {
        do {
            return try getSession().getTwoFactorConfig()
        } catch {
            print("something went wrong")
        }
        return nil
    }

    func isEmailEnabled() -> Bool {
        let config = getTwoFactorConfig()
        let email = config!["email"] as! [String: Any]
        if(email["enabled"] as! Int == 1 && email["confirmed"] as! Int == 1) {
            return true
        }
        return false
    }

    func isSMSEnabled() -> Bool {
        let config = getTwoFactorConfig()
        let sms = config!["sms"] as! [String: Any]
        if(sms["enabled"] as! Int == 1 && sms["confirmed"] as! Int == 1) {
            return true
        }
        return false
    }

    func isPhoneEnabled() -> Bool {
        let config = getTwoFactorConfig()
        let phone = config!["phone"] as! [String: Any]
        if(phone["enabled"] as! Int == 1 && phone["confirmed"] as! Int == 1) {
            return true
        }
        return false
    }

    func isGauthEnabled() -> Bool {
        let config = getTwoFactorConfig()
        let gauth = config!["gauth"] as! [String: Any]
        if(gauth["enabled"] as! Int == 1 && gauth["confirmed"] as! Int == 1) {
            return true
        }
        return false
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
