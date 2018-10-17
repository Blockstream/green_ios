//
//  SettingsStore.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/15/18.
//  Copyright © 2018 Blockstream inc. All rights reserved.
//

import Foundation
import PromiseKit

class SettingsStore {

    let sectionAccount = "Account"
        let accountImage = #imageLiteral(resourceName: "account")
        let accountCurrency = "Alternative Currency"
        let accountDenomination = "Show Bitcoin in"
        let accountFee = "Transaction Priority"
        let accountWatchOnly = "Watch-only login"
    let sectionSecurity = "Security"
        let securityImage = #imageLiteral(resourceName: "security")
        let securityRecovery = "Show Recovery Seed"
        let securityScreenLock = "Screen Lock"
        let securityTwoFactor = "Two-factor Authentication"
        let securitySupport = "Support"
        let securityLogout = "Automatically lock after"
    let sectionAdvanced = "Advanced"
        let advancedImage = #imageLiteral(resourceName: "advanced")
        let advancedSegwit = "Enable Segwit"
        let advancedNLock = "nLockTimeTransactions"
    let sectionAbout = "About"
        let aboutImage = #imageLiteral(resourceName: "about")
        let aboutVersion = "Version"
        let aboutTOS = "Terms of use"
        let aboutPrivacy = "Privacy Policy"

    let settingsCurrency = "settingsCurrency"
    let settingsDenomination = "settingsDenomination"
    let settingsWatchOnly = "settingsWatchOnly"
    let settingsFee = "settingsFee"

    let settingsRecovery = "settingsRecovery"
    let settingsScreenLock = "settingsScreenLock"
    let settingsTwoFactor = "settingsTwoFactor"
    let settingsAutolock = "settingsAutolock"
    let settingsSupport = "settingsSupport"

    let settingsNLockTime = "settingsNLockTime"

    let settingsVersion = "settingsVersion"
    let settingsTOS = "settingsTOS"
    let settingsPrivacy = "settingsPrivacy"

    let tosURL = "https://greenaddress.it/en/tos"
    let privacyPolicyURL = "https://greenaddress.it/en/privacy"
    let supportURL = "https://greenaddress.it/en/support"

    let denominationPrimary = "BTC"
    let denominationMilli = "mBTC"
    let denominationMicro = "uBTC"

    let feeMedium = "Medium"

    let screenLockSettingsValueDefault = "None"
    let screenLockSettingsValuePin = "Pin"
    let screenLockSettingsValueFaceId = "Face ID"
    let screenLockSettingsValueTouchId = "Touch ID"

    static let shared = SettingsStore()
    var currentExchange: String = ""
    var currentCurrency: String = ""
    var allSections: Array<SettingsSection> = Array<SettingsSection>()
    var allSettings: [String : SettingsItem] = [String : SettingsItem]()

    private init() { }

    func setCurrency(currency: String, exchange: String) -> Promise<Void> {
       return wrap{ try getSession().changeSettingsPricingSource(currency: currency, exchange: exchange)}.done {
        self.allSettings[self.settingsCurrency] = SettingsItem(settingsName: self.settingsCurrency, property: ["currency": currency, "exchange": exchange], text: self.accountCurrency, secondaryText: currency)
            self.loadAllSections()
            self.writeSettingsToDisk()
            }
    }

    func setDenominationSettings(denomination: String) {
        if (denomination != denominationPrimary && denomination != denominationMilli && denomination != denominationMicro) {
            return
        }
        let denominationProperty = [settingsDenomination: denomination]
        allSettings[settingsDenomination] = SettingsItem(settingsName: settingsDenomination, property: denominationProperty, text: accountDenomination, secondaryText: denomination)
        loadAllSections()
        writeSettingsToDisk()
    }

    func stringForScreenLockSettings(screenLock: ScreenLock) -> String{
        if (screenLock == ScreenLock.None) {
            return "None"
        } else if (screenLock == ScreenLock.FaceID) {
            return "FaceID"
        } else if (screenLock == ScreenLock.TouchID) {
            return "TouchID"
        } else if (screenLock == ScreenLock.Pin) {
            return "PIN"
        } else if (screenLock == ScreenLock.all) {
            return "Bio&PIN"
        }
        return ""
    }

    func setScreenLockSettings(screenLock: ScreenLock) {
        let screenLockProperty = [settingsScreenLock: String(screenLock.rawValue)]
        let setting = SettingsItem(settingsName: settingsScreenLock, property: screenLockProperty, text: securityScreenLock, secondaryText: stringForScreenLockSettings(screenLock: screenLock))
        allSettings[settingsScreenLock] = setting
        loadAllSections()
        writeSettingsToDisk()
    }

    func setFeeSettings(satoshi: Int, priority: TransactionPriority) {
        if (priority == TransactionPriority.Low || priority == TransactionPriority.Medium || priority == TransactionPriority.High) {
            let setting = SettingsItem(settingsName: settingsFee, property: ["priority" : priority.rawValue, "satoshi" : String(0)], text: accountFee, secondaryText: priority.rawValue)
            allSettings[settingsFee] = setting
            loadAllSections()
            writeSettingsToDisk()
        } else {
            let setting = SettingsItem(settingsName: settingsFee, property: ["priority" : priority.rawValue, "satoshi" : String(satoshi)], text: accountFee, secondaryText: priority.rawValue)
            allSettings[settingsFee] = setting
            loadAllSections()
            writeSettingsToDisk()
        }
    }

    func setAutolockSettings(time: Int, type: AutoLock) {
        if(type == AutoLock.Custom) {
            let setting = SettingsItem(settingsName: settingsAutolock, property: ["type" : type.rawValue, "time": String(time)], text: securityLogout, secondaryText: type.rawValue)
            allSettings[settingsAutolock] = setting
            loadAllSections()
            writeSettingsToDisk()
        } else {
            let setting = SettingsItem(settingsName: settingsAutolock, property: ["type" : type.rawValue, "time": String(timeForAutolock(lock: type))], text: securityLogout, secondaryText: type.rawValue)
            allSettings[settingsAutolock] = setting
            loadAllSections()
            writeSettingsToDisk()
        }
    }

    func getAutolockSettings() -> (AutoLock, Int) {
        let setting = allSettings[settingsAutolock]
        let lock = setting!.settingsProperty["type"]!
        let time = Int(setting!.settingsProperty["time"]!)
        return (AutoLock(rawValue: lock)!, time!)
    }

    func getFeeSettings() -> (TransactionPriority, Int) {
        let setting = allSettings[settingsFee]
        let priority = setting!.settingsProperty["priority"]!
        let satoshi = Int(setting!.settingsProperty["satoshi"]!)
        return (TransactionPriority(rawValue: priority)!, satoshi!)
    }

    func getScreenLockSetting() -> ScreenLock {
        let setting = allSettings[settingsScreenLock]
        let property = setting?.settingsProperty[settingsScreenLock]
        let raw = UInt32(property!)
        return ScreenLock(rawValue: raw!)!
    }

    func getDenominationSettings() -> String {
        return (allSettings[settingsDenomination]?.settingsProperty[settingsDenomination])!
    }

    func getCurrencySettings() -> SettingsItem? {
        return allSettings[settingsCurrency]
    }

    func getCurrencyString() -> String {
        return (allSettings[settingsCurrency]?.settingsProperty["currency"])!
    }

    func defaultFeeSettings() -> SettingsItem {
        return SettingsItem(settingsName: settingsFee, property: ["priority" : TransactionPriority.Medium.rawValue, "satoshi" : String(0)], text: accountFee, secondaryText: TransactionPriority.Medium.rawValue)
    }

    func timeForAutolock(lock: AutoLock) -> Int {
        if (lock == AutoLock.minute) {
            return 60
        } else if (lock == AutoLock.twoMinutes) {
            return 120
        } else if (lock == AutoLock.fiveMinutes) {
            return 300
        } else {
            return 600
        }
    }

    func defaultAutolockSettings() -> SettingsItem {
        let lock = AutoLock.fiveMinutes
        return SettingsItem(settingsName: settingsAutolock, property: ["type" : lock.rawValue, "time": String(timeForAutolock(lock: lock))], text: securityLogout, secondaryText: lock.rawValue)
    }

    func defaultDenominationSettings() -> SettingsItem {
        let denominationProperty = [settingsDenomination: denominationPrimary]
        return SettingsItem(settingsName: settingsDenomination, property: denominationProperty, text: accountDenomination, secondaryText: denominationPrimary)
    }

    func defaultCurrencySettings() -> SettingsItem {
        let currencyProperty = ["exchange": "BITSTAMP", "currency": "USD"]
        return SettingsItem(settingsName: settingsCurrency, property: currencyProperty, text: accountCurrency, secondaryText: "USD")
    }

    func defaultWatchOnlySettings() -> SettingsItem {
        return SettingsItem(settingsName: settingsWatchOnly, property: [settingsWatchOnly : "false"], text: accountWatchOnly, secondaryText: "")
    }

    func defaultRecoverySeed() -> SettingsItem {
        return SettingsItem(settingsName: settingsRecovery, property:[String : String](), text: securityRecovery, secondaryText: "")
    }

    func defaultScreenLock() -> SettingsItem {
        return SettingsItem(settingsName: settingsScreenLock, property:[settingsScreenLock : String(ScreenLock.None.rawValue)], text: securityScreenLock, secondaryText: stringForScreenLockSettings(screenLock: ScreenLock.None))
    }

    func defaultTwoFactor() -> SettingsItem {
        return SettingsItem(settingsName: settingsTwoFactor, property:[String : String](), text: securityTwoFactor, secondaryText: "None")
    }

    func defaultSupport() -> SettingsItem {
        return SettingsItem(settingsName: settingsSupport, property:[String : String](), text: securitySupport, secondaryText: "")
    }

    func defaultNlockTime() -> SettingsItem {
        return SettingsItem(settingsName: settingsNLockTime, property:[String : String](), text: advancedNLock, secondaryText: "")
    }

    func defaultVersion() -> SettingsItem {
        let version = Bundle.main.infoDictionary!["CFBundleShortVersionString"]!
        return SettingsItem(settingsName: settingsVersion, property:[String : String](), text: aboutVersion, secondaryText: version as! String)
    }

    func defaultTOS() -> SettingsItem {
        return SettingsItem(settingsName: settingsTOS, property:[String : String](), text: aboutTOS, secondaryText: "")
    }

    func defaultPrivacy() -> SettingsItem {
        return SettingsItem(settingsName: settingsPrivacy, property:[String : String](), text: aboutPrivacy, secondaryText: "")
    }

    func createAccountSection() -> SettingsSection {
        var accountSettings = Array<SettingsItem>()
        let currency = allSettings[settingsCurrency] == nil ? defaultCurrencySettings() : allSettings[settingsCurrency]
        let denomination = allSettings[settingsDenomination] == nil ? defaultDenominationSettings() : allSettings[settingsDenomination]
        let fee = allSettings[settingsFee] == nil ? defaultFeeSettings() : allSettings[settingsFee]
        let watch = allSettings[settingsWatchOnly] == nil ? defaultWatchOnlySettings() : allSettings[settingsWatchOnly]
        accountSettings.append(currency!)
        accountSettings.append(denomination!)
        accountSettings.append(fee!)
        accountSettings.append(watch!)
        allSettings[settingsCurrency] = currency
        allSettings[settingsDenomination] = denomination
        allSettings[settingsFee] = fee
        allSettings[settingsWatchOnly] = watch
        let section = SettingsSection(sectionName: sectionAccount, settingsInSection: accountSettings)
        return section
    }

    func createSecuritySection() -> SettingsSection {
        var securitySettings = Array<SettingsItem>()
        let recovery = allSettings[settingsRecovery] == nil ? defaultRecoverySeed() : allSettings[settingsRecovery]
        let screenLock = allSettings[settingsScreenLock] == nil ? defaultScreenLock() : allSettings[settingsScreenLock]

        var twoFactor: SettingsItem? = nil
        if(AccountStore.shared.isTwoFactorEnabled()) {
            twoFactor = SettingsItem(settingsName: settingsTwoFactor, property:[String : String](), text: securityTwoFactor, secondaryText: "Enabled")
        } else {
            twoFactor = defaultTwoFactor()
        }
        let autolock = allSettings[settingsAutolock] == nil ? defaultAutolockSettings() : allSettings[settingsAutolock]
        let support = allSettings[settingsSupport] == nil ? defaultSupport() : allSettings[settingsSupport]
        securitySettings.append(recovery!)
        securitySettings.append(screenLock!)
        securitySettings.append(twoFactor!)
        securitySettings.append(autolock!)
        securitySettings.append(support!)
        allSettings[settingsRecovery] = recovery
        allSettings[settingsScreenLock] = screenLock
        allSettings[settingsTwoFactor] = twoFactor
        allSettings[settingsSupport] = support
        allSettings[settingsAutolock] = autolock
        let section = SettingsSection(sectionName: sectionSecurity, settingsInSection: securitySettings)
        return section
    }

    func createAdvancedSection() -> SettingsSection {
        var advancedSettings = Array<SettingsItem>()
        let nlock = allSettings[settingsNLockTime] == nil ? defaultNlockTime() : allSettings[settingsNLockTime]
        advancedSettings.append(nlock!)
        allSettings[settingsNLockTime] = nlock
        let section = SettingsSection(sectionName: sectionAdvanced, settingsInSection: advancedSettings)
        return section
    }

    func createAboutSection() -> SettingsSection {
        var aboutSettings = Array<SettingsItem>()
        let version = allSettings[settingsVersion] == nil ? defaultVersion() : allSettings[settingsVersion]
        let tos = allSettings[settingsTOS] == nil ? defaultTOS() : allSettings[settingsTOS]
        let privacy = allSettings[settingsPrivacy] == nil ? defaultPrivacy() : allSettings[settingsPrivacy]
        aboutSettings.append(version!)
        aboutSettings.append(tos!)
        aboutSettings.append(privacy!)
        allSettings[settingsVersion] = version
        allSettings[settingsTOS] = tos
        allSettings[settingsPrivacy] = privacy
        let section = SettingsSection(sectionName: sectionAbout, settingsInSection: aboutSettings)
        return section
    }

    func getAllSections() -> Array<SettingsSection> {
        return allSections
    }

    func loadSettingsFromDisk() ->  [String: SettingsItem]? {
        guard let url = Storage.getDocumentsURL()?.appendingPathComponent("settings.json") else {
            return nil //initialize settings defaults?
        }
       /* do {
            try FileManager.default.removeItem(at: url)
        } catch let error as NSError {
            print("Error: \(error.domain)")
        }*/
        let decoder = JSONDecoder()
        do {
            // 2. Retrieve the data on the file in this path (if there is any)
            let data = try Data(contentsOf: url, options: [])
            // 3. Decode an array of Posts from this Data
            let settings = try decoder.decode( [String: SettingsItem].self, from: data)
            return settings
        } catch {
            return nil //initialize settings ?
        }
    }

    func writeSettingsToDisk() {
        guard let url = Storage.getDocumentsURL()?.appendingPathComponent("settings.json") else {
            return
        }
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(allSettings)
            // 3. Write this data to the url specified in step 1
            try data.write(to: url, options: [])
        } catch {
            print("error writing notifications to disk")
        }
    }

    func loadAllSections() {
        allSections.removeAll()
        allSections.append(createAccountSection())
        allSections.append(createSecuritySection())
        allSections.append(createAdvancedSection())
        allSections.append(createAboutSection())
    }

    func initSettingsStore() {
        guard let all = loadSettingsFromDisk() else {
            //loadDefaultSettings()
            loadAllSections()
            return
        }
        allSettings = all
        loadAllSections()
    }

}

class SettingsItem: Codable {
    var settingsName: String
    var settingsProperty: [String: String]
    var text: String
    var secondaryText: String

    init(settingsName: String, property: [String: String], text: String, secondaryText: String) {
        self.settingsName = settingsName
        self.settingsProperty = property
        self.text = text
        self.secondaryText = secondaryText
    }
}

class SettingsSection: Codable {
    var sectionName: String
    var settingsInSection: Array<SettingsItem>

    init(sectionName: String, settingsInSection: Array<SettingsItem>) {
        self.sectionName = sectionName
        self.settingsInSection = settingsInSection
    }
}

public enum ScreenLock: UInt32 {
    case None = 0
    case Pin = 1
    case TouchID = 2
    case FaceID = 3
    case all = 4
}

public enum TransactionPriority: String {
    case Low = "Low"
    case Medium = "Medium"
    case High = "High"
    case Custom = "Custom"
}

public enum AutoLock: String {
    case minute = "1 Minute"
    case twoMinutes = "2 Minutes"
    case fiveMinutes = "5 Minutes"
    case tenMinutes = "10 Minutes"
    case Custom = "Custom"
}

