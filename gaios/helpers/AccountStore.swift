import Foundation
import PromiseKit

class AccountStore {

    static let shared = AccountStore()
    var wallets = [WalletItem]()
    var blockHeight: UInt32 = 0
    var isWatchOnly: Bool = false
    public let GDKQueue = DispatchQueue(label: "gdk",attributes: .concurrent)

    var isResetInProgress: Bool = false
    var isResetDisputed: Bool = false
    var resetDaysRemaining: Int = 0

    func setTwoFactorResetData(isReset: Bool, isDisputed: Bool, days: Int) {
        isResetInProgress = isReset
        isResetDisputed = isDisputed
        resetDaysRemaining = days
    }

    func getTwoFactorResetData() -> (isReset: Bool, isDisputed: Bool, days: Int) {
        return(isResetInProgress, isResetDisputed, resetDaysRemaining)
    }

    func getSubaccounts() -> Promise<[WalletItem]> {
        let bgq = DispatchQueue.global(qos: .background)
        return Guarantee().compactMap(on: bgq) {
            try getSession().getSubaccounts()
        }.compactMap(on: bgq) { data in
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let accounts = try JSONDecoder().decode(Wallets.self, from: jsonData)
            self.wallets = accounts.array
            return self.wallets
        }
    }

    func getWallets(cached: Bool) -> Promise<[WalletItem]> {
        // FIXME: should this be cached == true?
        if wallets.count > 0 && cached == false {
            return Promise<[WalletItem]> { seal in
                seal.fulfill(wallets)
            }
        }
        return getSubaccounts()
    }

    func getBlockheight() -> UInt32 {
        return blockHeight
    }

    func setBlockHeight(height: UInt32) {
        blockHeight = height
    }

    func getFeeRateHigh() -> UInt64 {
        do {
            let json = try getSession().getFeeEstimates()
            let estimates = json!["fees"] as! NSArray
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
            let estimates = json!["fees"] as! NSArray
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
            let estimates = json!["fees"] as! NSArray
            let result = estimates[12] as! UInt64
            return result
        } catch {
            print("something went wrong")
        }
        return 0
    }

    func getFeeRateMin() -> UInt64 {
        do {
            let json = try getSession().getFeeEstimates()
            let estimates = json!["fees"] as! NSArray
            let result = estimates[0] as! UInt64
            return result
        } catch {
            print("something went wrong")
        }
        return 0
    }

    func dateFromTimestamp(date: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.date(from: date)!
    }

    func enableEmailTwoFactor(email: String) throws -> TwoFactorCall? {
        //nlohmann::json subconfig = { { "enabled", true }, { "confirmed", true }, { "data", data } };
        let dict = ["enabled": true, "confirmed": true, "data": email] as [String : Any]
        return try getSession().changeSettingsTwoFactor(method: "email", details: dict)
    }

    func disableEmailTwoFactor() throws -> TwoFactorCall? {
        let dict = ["enabled": false] as [String : Any]
        return try getSession().changeSettingsTwoFactor(method: "email", details: dict)
    }

    func enableSMSTwoFactor(phoneNumber: String) throws -> TwoFactorCall? {
        //nlohmann::json subconfig = { { "enabled", true }, { "confirmed", true }, { "data", data } };
        let dict = ["enabled": true, "confirmed": true, "data": phoneNumber] as [String : Any]
        return try getSession().changeSettingsTwoFactor(method: "sms", details: dict)
    }

    func disableSMSTwoFactor() throws -> TwoFactorCall? {
        let dict = ["enabled": false] as [String : Any]
        return try getSession().changeSettingsTwoFactor(method: "sms", details: dict)
    }

    func enablePhoneCallTwoFactor(phoneNumber: String) throws -> TwoFactorCall? {
        let dict = ["enabled": true, "confirmed": true, "data": phoneNumber] as [String : Any]
        return try getSession().changeSettingsTwoFactor(method: "phone", details: dict)
    }

    func disablePhoneCallTwoFactor() throws -> TwoFactorCall? {
        let dict = ["enabled": false] as [String : Any]
        return try getSession().changeSettingsTwoFactor(method: "phone", details: dict)
    }

    func enableGauthTwoFactor() throws -> TwoFactorCall? {
        let config = try getSession().getTwoFactorConfig()
        let gauth = config!["gauth"] as! [String: Any]
        let gauthdata = gauth["data"] as! String
        let dict = ["enabled": true, "confirmed": true, "data": gauthdata] as [String : Any]
        return try getSession().changeSettingsTwoFactor(method: "gauth", details: dict)
    }

    func disableGauthTwoFactor() throws -> TwoFactorCall? {
        let dict = ["enabled": false] as [String : Any]
        return try getSession().changeSettingsTwoFactor(method: "gauth", details: dict)
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

    func getGauthOTP() -> String? {
        let config = getTwoFactorConfig()
        if (config == nil) {
            return nil
        }
        let gauth = config!["gauth"] as! [String: Any]
        let gauthdata = gauth["data"] as! String
        return gauthdata
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
        if(config == nil) {
            return false
        }
        let email = config!["email"] as! [String: Any]
        if(email["enabled"] as! Int == 1 && email["confirmed"] as! Int == 1) {
            return true
        }
        return false
    }

    func isSMSEnabled() -> Bool {
        let config = getTwoFactorConfig()
        if(config == nil) {
            return false
        }
        let sms = config!["sms"] as! [String: Any]
        if(sms["enabled"] as! Int == 1 && sms["confirmed"] as! Int == 1) {
            return true
        }
        return false
    }

    func isPhoneEnabled() -> Bool {
        let config = getTwoFactorConfig()
        if(config == nil) {
            return false
        }
        let phone = config!["phone"] as! [String: Any]
        if(phone["enabled"] as! Int == 1 && phone["confirmed"] as! Int == 1) {
            return true
        }
        return false
    }

    func isGauthEnabled() -> Bool {
        let config = getTwoFactorConfig()
        if(config == nil) {
            return false
        }
        let gauth = config!["gauth"] as! [String: Any]
        if(gauth["enabled"] as! Int == 1 && gauth["confirmed"] as! Int == 1) {
            return true
        }
        return false
    }

    func isTwoFactorEnabled() -> Bool {
        let config = getTwoFactorConfig()
        if(config == nil) {
            return false
        }
        let enabled = config!["any_enabled"] as! Bool
        return enabled
    }

    func getTwoFactorLimit() -> (isFiat: Bool, amount: String) {
        if let config = getTwoFactorConfig() {
            let limits = config["limits"] as! [String: Any]
            let isFiat = limits["is_fiat"] as! Bool
            let btcString = limits["btc"] as! String
            let fiatString = limits["fiat"] as! String
            return isFiat ? (isFiat, fiatString) : (isFiat, btcString)
        } else {
            return (false, "0")
        }
    }

    func twoFactorsEnabledCount() -> Int {
        if let config = getTwoFactorConfig() {
            let methods = config["enabled_methods"] as! NSArray
            return methods.count
        }
        return 0
    }

    @objc func incomingTransaction(_ notification: NSNotification) {
        print(notification.userInfo ?? "")
        if let dict = notification.userInfo as NSDictionary? {
            if let accounts = dict["subaccounts"] as? NSArray {
                print(accounts)
                for acc in accounts {
                    let pointer = acc as! Int
                    let p = UInt32(pointer)
                    DispatchQueue.global(qos: .background).async {
                        wrap {
                            try getSession().getReceiveAddress(subaccount: p)
                        }.done { address in
                            DispatchQueue.main.async {
                                // FIXME: out of bounds access
                                self.wallets[pointer].receiveAddress = address
                                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "addressChanged"), object: nil, userInfo: ["pointer" : pointer])
                            }
                        }
                    }
                }
            }
        }
    }

    func initializeAccountStore() {
        SettingsStore.shared.initSettingsStore()
        NotificationStore.shared.initializeNotificationStore()
        NotificationCenter.default.addObserver(self, selector: #selector(self.incomingTransaction(_:)), name: NSNotification.Name(rawValue: "incomingTX"), object: nil)
    }
}
