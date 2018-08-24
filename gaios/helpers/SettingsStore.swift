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
    let currencySettings = "currencySettings"
    let denominationSettings = "denominationSettings"
    let screenLockSettings = "screenLockSettings"
    let twoFactorSettings = "twoFactorSettings"
    let segwitSettings = "segwitSettings"
    let nlockTimeSettings = "nLockTimeSettings"
    let spvSettings = "spvSettings"
    let tosURL = "tosURL"
    let privacyPolicyURL = "privacyPolicyURL"

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
    var allSettings: [String: SettingsItem] = [String: SettingsItem]()


    private init() { }

    func setCurrency(currency: String, exchange: String) -> Promise<Void> {
       return wrap{ try getSession().set_pricing_source(currency: currency, exchange: exchange)}.done {
            self.allSettings[self.currencySettings] = SettingsItem(settingsName: self.currencySettings, property: ["currency": currency, "exchange": exchange])
            self.writeSettingsToDisk()
            }
    }

    func getCurrencySettings() -> SettingsItem? {
        return allSettings[currencySettings]
    }

    func getCurrencyString() -> String? {
        return allSettings[currencySettings]?.settingsProperty["currency"]
    }

    func getAvailableCurrency() {

    }

    func getDefaultSettings() -> [String: SettingsItem] {
        var defaults: [String: SettingsItem] = [String: SettingsItem]()
        let currencyProperty = ["exchange": "bitstamp", "currency": "USD"]
        let currency = SettingsItem(settingsName: currencySettings, property: currencyProperty)
        let denomination = SettingsItem(settingsName: denominationSettings, property: [denominationSettings: denominationPrimary])
        let screenLock = SettingsItem(settingsName: screenLockSettings, property: [screenLockSettings: screenLockSettingsValueDefault])

        defaults[currency.settingsName] = currency
        defaults[denomination.settingsName] = denomination
        defaults[screenLock.settingsName] = screenLock

        return defaults
    }

    func loadSettingsFromDisk() -> [String: SettingsItem] {
        guard let url = Storage.getDocumentsURL()?.appendingPathComponent("settings.json") else {
            return getDefaultSettings() //initialize settings defaults?
        }
        let decoder = JSONDecoder()
        do {
            // 2. Retrieve the data on the file in this path (if there is any)
            let data = try Data(contentsOf: url, options: [])
            // 3. Decode an array of Posts from this Data
            let settings = try decoder.decode( [String: SettingsItem].self, from: data)
            return settings
        } catch {
            return getDefaultSettings() //initialize settings ?
        }
    }

    func writeSettingsToDisk() {
        guard let url = Storage.getDocumentsURL()?.appendingPathComponent("settings.json") else {
            return
        }
        let encoder = JSONEncoder()
        do {
            let settingsToWrite = allSettings.values
            let data = try encoder.encode(allSettings)
            // 3. Write this data to the url specified in step 1
            try data.write(to: url, options: [])
        } catch {
            print("error writing notifications to disk")
        }
    }

    func initSettingsStore() {
        allSettings = loadSettingsFromDisk()
    }

}

class SettingsItem: Codable{
    var settingsName: String
    var settingsProperty: [String: String]

    init(settingsName: String, property: [String: String]) {
        self.settingsName = settingsName
        self.settingsProperty = property
    }
}

