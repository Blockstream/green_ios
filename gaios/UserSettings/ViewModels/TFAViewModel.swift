import Foundation
import UIKit
import core
import gdk

enum TFASection: Int, CaseIterable {
    case header
    case warnMulti
    case networkSelect
    case methods
    case empty
    case reset
    case threshold
    case expiry
    case infoExpire
    case recActions
}
class TFAViewModel {

    var wm: WalletManager { WalletManager.current! }

    var sessionBitcoin: SessionManager? { wm.sessions["mainnet"] }
    var sessionLiquid: SessionManager? { wm.sessions["liquid"] }
    var networks: [NetworkSecurityCase] { wm.testnet ? [.testnetMS, .testnetLiquidMS] : [.bitcoinMS, .liquidMS] }
    var sessions: [SessionManager] { networks.compactMap { wm.sessions[$0.network] }}
    var selectedSegmentIndex = 0
    var session: SessionManager {
        sessions[selectedSegmentIndex]
    }
    var csvTypes: [CsvTime] { CsvTime.all(for: session.gdkNetwork) }
    var csvValues: [Int] { CsvTime.values(for: session.gdkNetwork) ?? [] }
    var factors: [TwoFactorItem]?
    var twoFactorConfig: TwoFactorConfig?
    private var newCsv: Int?
    private var currentCsv: Int?
    var sections: [TFASection] {
        var list: [TFASection] = [.header, .warnMulti, .networkSelect, .methods, .empty]
        let liquid = session.gdkNetwork.liquid
        if !(!session.logged || liquid) {
            list.append(.reset)
            list.append(.threshold)
            list.append(.expiry)
        }
        if session.logged {
            list.append(.infoExpire)
            list.append(.recActions)
        }
        return list
    }
    var refreshableSections: [TFASection] {
        return [.reset, .threshold, .expiry]
    }
    func getTwoFactors() async throws -> [TwoFactorItem] {
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
    var threshold: String {
        if let twoFactorConfig = twoFactorConfig,
            twoFactorConfig.anyEnabled,
           let settings = session.settings {
            let limits = twoFactorConfig.limits
            var (amount, den) = ("", "")
            if limits.isFiat {
                let balance = Balance.fromFiat(limits.fiat ?? "0")
                (amount, den) = balance?.toDenom() ?? ("", "")
            } else {
                let denom = settings.denomination.rawValue
                let assetId = session.gdkNetwork.getFeeAsset()
                let balance = Balance.fromDenomination(limits.get(TwoFactorConfigLimits.CodingKeys(rawValue: denom)!) ?? "0", assetId: assetId)
                (amount, den) = balance?.toFiat() ?? ("", "")
            }
            return String(format: "%@ %@", amount, den)
        }
        return ""
    }
    func setCsvTimeLock(csv: CsvTime) async throws {
        try await session.setCSVTime(value: csv.value(for: session.gdkNetwork)!)
        _ = try await session.loadSettings()
        newCsv = nil
        currentCsv = csv.value(for: session.gdkNetwork)
    }
    func resetTwoFactor(session: SessionManager, email: String) async throws {
        try await session.resetTwoFactor(email: email, isDispute: false)
        try await session.loadTwoFactorConfig()
    }
    func disable(type: TwoFactorType) async throws {
        let config = TwoFactorConfigItem(enabled: false, confirmed: false, data: "")
        let params = ChangeSettingsTwoFactorParams(method: type, config: config)
        try await session.changeSettingsTwoFactor(params)
        try await session.loadTwoFactorConfig()
    }
}
