import Foundation
import UIKit
import core
import gdk

class TwoFactorSettingsViewModel {

    // load wallet manager for current logged session
    var wm: WalletManager { WalletManager.current! }

    // current multisig session
    var sessionBitcoin: SessionManager? { wm.sessions["mainnet"] }
    var sessionLiquid: SessionManager? { wm.sessions["liquid"] }
    var networks: [NetworkSecurityCase] { wm.testnet ? [.testnetMS, .testnetLiquidMS] : [.bitcoinMS, .liquidMS] }
    var sessions: [SessionManager] { networks.compactMap { wm.sessions[$0.network] }}

    private var csvTypes = [CsvTime]()
    private var csvValues = [Int]()
    private var newCsv: Int?
    private var currentCsv: Int?
    var twoFactorConfig: TwoFactorConfig?

    func getTwoFactors(session: SessionManager) async throws -> [TwoFactorItem] {
        if !session.logged {
            return []
        }
        let twoFactorConfig = try await session.loadTwoFactorConfig()
        self.twoFactorConfig = twoFactorConfig
        guard let twoFactorConfig = twoFactorConfig else {
            return []
        }
        return [ TwoFactorItem(name: "id_email".localized, enabled: twoFactorConfig.email.enabled, confirmed: twoFactorConfig.email.confirmed, maskedData: twoFactorConfig.email.data, type: TwoFactorType.email),
                 TwoFactorItem(name: "id_sms".localized, enabled: twoFactorConfig.sms.enabled, confirmed: twoFactorConfig.sms.confirmed, maskedData: twoFactorConfig.sms.data, type: TwoFactorType.sms),
                 TwoFactorItem(name: "id_call".localized, enabled: twoFactorConfig.phone.enabled, confirmed: twoFactorConfig.phone.confirmed, maskedData: twoFactorConfig.phone.data, type: TwoFactorType.phone),
                 TwoFactorItem(name: "id_authenticator_app".localized, enabled: twoFactorConfig.gauth.enabled, confirmed: twoFactorConfig.gauth.confirmed, type: TwoFactorType.gauth) ]
    }

    func isSmsOnly(_ items: [TwoFactorItem]) -> Bool {
        (items.filter { $0.enabled == true && $0.confirmed == true && $0.type == .sms}).count == 1
    }

    func disable(session: SessionManager, type: TwoFactorType) async throws {
        let config = TwoFactorConfigItem(enabled: false, confirmed: false, data: "")
        let params = ChangeSettingsTwoFactorParams(method: type, config: config)
        try await session.changeSettingsTwoFactor(params)
        try await session.loadTwoFactorConfig()
    }

    func setCsvTimeLock(session: SessionManager, csv: CsvTime) async throws {
        try await session.setCSVTime(value: csv.value(for: session.gdkNetwork)!)
        try await session.loadSettings()
        newCsv = nil
        currentCsv = csv.value(for: session.gdkNetwork)
    }

    func resetTwoFactor(session: SessionManager, email: String) async throws {
        try await session.resetTwoFactor(email: email, isDispute: false)
        try await session.loadTwoFactorConfig()
    }

    func setEmail(session: SessionManager, email: String, isSetRecovery: Bool) async throws {
        let config = TwoFactorConfigItem(enabled: isSetRecovery ? false : true, confirmed: true, data: email)
        let params = ChangeSettingsTwoFactorParams(method: .email, config: config)
        try await session.changeSettingsTwoFactor(params)
        try await session.loadTwoFactorConfig()
    }

    func setPhoneSms(session: SessionManager, countryCode: String, phone: String, sms: Bool) async throws {
        let config = TwoFactorConfigItem(enabled: true, confirmed: true, data: countryCode + phone)
        let params = ChangeSettingsTwoFactorParams(method: sms ? .sms : .phone, config: config)
        try await session.changeSettingsTwoFactor(params)
        try await session.loadTwoFactorConfig()
    }

    func setGauth(session: SessionManager, gauth: String) async throws {
        let config = TwoFactorConfigItem(enabled: true, confirmed: true, data: gauth)
        let params = ChangeSettingsTwoFactorParams(method: .gauth, config: config)
        try await session.changeSettingsTwoFactor(params)
        try await session.loadTwoFactorConfig()
    }
}
