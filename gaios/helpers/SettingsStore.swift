//
//  SettingsStore.swift
//  gaios
//
//  Created by Strahinja Markovic on 8/23/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import PromiseKit

class SettingsStore {

    let sectionAccount = "Account"
        let accountImage = #imageLiteral(resourceName: "account")
        let accountCurrency = "Alternative Currency"
        let accountDenomination = "Show Bitcoin in"
        let accountWatchOnly = "Watch-only login"
    let sectionSecurity = "Security"
        let securityImage = #imageLiteral(resourceName: "security")
        let securityRecovery = "Show Recovery Seed"
        let securityScreenLock = "Screen Lock"
        let securityTwoFactor = "Two-factor Authentication"
        let securitySupport = "Support"
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

    let settingsRecovery = "settingsRecovery"
    let settingsScreenLock = "settingsScreenLock"
    let settingsTwoFactor = "settingsTwoFactor"
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

    func getDenominationSettings() -> String {
        return (allSettings[settingsDenomination]?.settingsProperty[settingsDenomination])!
    }

    func getCurrencySettings() -> SettingsItem? {
        return allSettings[settingsCurrency]
    }

    func getCurrencyString() -> String? {
        return allSettings[settingsCurrency]?.settingsProperty["currency"]
    }

    func defaultDenominationSettings() -> SettingsItem {
        let denominationProperty = [settingsDenomination: denominationPrimary]
        return SettingsItem(settingsName: settingsDenomination, property: denominationProperty, text: accountDenomination, secondaryText: denominationPrimary)
    }

    func defaultCurrencySettings() -> SettingsItem {
        let currencyProperty = ["exchange": "bitstamp", "currency": "USD"]
        return SettingsItem(settingsName: settingsCurrency, property: currencyProperty, text: accountCurrency, secondaryText: "USD")
    }

    func defaultWatchOnlySettings() -> SettingsItem {
        return SettingsItem(settingsName: settingsWatchOnly, property: [settingsWatchOnly : "false"], text: accountWatchOnly, secondaryText: "")
    }

    func defaultRecoverySeed() -> SettingsItem {
        return SettingsItem(settingsName: settingsRecovery, property:[String : String](), text: securityRecovery, secondaryText: "")
    }

    func defaultScreenLock() -> SettingsItem {
        return SettingsItem(settingsName: settingsScreenLock, property:[String : String](), text: securityScreenLock, secondaryText: "None")
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
        let watch = allSettings[settingsWatchOnly] == nil ? defaultWatchOnlySettings() : allSettings[settingsWatchOnly]
        accountSettings.append(currency!)
        accountSettings.append(denomination!)
        accountSettings.append(watch!)
        allSettings[settingsCurrency] = currency
        allSettings[settingsDenomination] = denomination
        allSettings[settingsWatchOnly] = watch
        let section = SettingsSection(sectionName: sectionAccount, settingsInSection: accountSettings)
        return section
    }

    func createSecuritySection() -> SettingsSection {
        var securitySettings = Array<SettingsItem>()
        let recovery = allSettings[settingsRecovery] == nil ? defaultRecoverySeed() : allSettings[settingsRecovery]
        let screenLock = allSettings[settingsScreenLock] == nil ? defaultScreenLock() : allSettings[settingsScreenLock]
        let twoFactor = allSettings[settingsTwoFactor] == nil ? defaultTwoFactor() : allSettings[settingsTwoFactor]
        let support = allSettings[settingsSupport] == nil ? defaultSupport() : allSettings[settingsSupport]
        securitySettings.append(recovery!)
        securitySettings.append(screenLock!)
        securitySettings.append(twoFactor!)
        securitySettings.append(support!)
        allSettings[settingsRecovery] = recovery
        allSettings[settingsScreenLock] = screenLock
        allSettings[settingsTwoFactor] = twoFactor
        allSettings[settingsSupport] = support
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

