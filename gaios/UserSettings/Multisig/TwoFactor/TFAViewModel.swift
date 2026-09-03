import Foundation
import UIKit
import core


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

@MainActor
class TFAViewModel {

    let mainWallet: Wallet
    let wm: WalletManager
    var selectedSegmentIndex = 0

    var networks: [NetworkId] { wm.multisigNetworkIds }
    var selectedNetwork: NetworkId { networks[selectedSegmentIndex] }
    var selectedBackend: GdkNetworkBackend? { wm.gdkNetworkBackendOrNil(selectedNetwork) }
    var selectedCsvTypes: [CsvTime] {
        CsvTime.all(for: selectedNetwork.gdkNetwork)
    }
    var selectedCsvValues: [Int] {
        CsvTime.values(for: selectedNetwork.gdkNetwork) ?? []
    }

    var selectedFactors: [TwoFactorItem] {
        Self.factors(from: selectedBackend?.twoFactorConfig)
    }
    var selectedThreshold: String {
        Self.threshold(
            from: selectedBackend?.twoFactorConfig,
            settings: selectedBackend?.settings,
            gdkNetwork: selectedBackend?.gdkNetwork
        )
    }
    var selectedCsv: Int? {
        selectedBackend?.settings?.csvtime
    }
    var isLiquid: Bool { selectedNetwork.liquid }
    var gdkNetwork: GdkNetwork { selectedNetwork.gdkNetwork }

    var sections: [TFASection] {
        var list: [TFASection] = [.header, .warnMulti, .networkSelect, .methods, .empty]
        if selectedBackend?.isLoggedIn == true {
            list.append(.reset)
            if selectedBackend?.network.liquid == false {
                list.append(.threshold)
            }
            list.append(.expiry)
            list.append(.infoExpire)
            list.append(.recActions)
        }
        return list
    }

    internal init(mainWallet: Wallet, wm: WalletManager, selectedSegmentIndex: Int = 0) {
        self.mainWallet = mainWallet
        self.wm = wm
        self.selectedSegmentIndex = selectedSegmentIndex
    }

    func selectNetwork(_ index: Int) {
        guard networks.indices.contains(index), selectedSegmentIndex != index else { return }
        selectedSegmentIndex = index
    }

    private static func factors(from twoFactorConfig: TwoFactorConfig?) -> [TwoFactorItem] {
        guard let twoFactorConfig else {
            return []
        }
        return [
            TwoFactorItem(name: "id_email".localized, enabled: twoFactorConfig.email.enabled, confirmed: twoFactorConfig.email.confirmed, maskedData: twoFactorConfig.email.data, type: TwoFactorType.email),
            TwoFactorItem(name: "id_sms".localized, enabled: twoFactorConfig.sms.enabled, confirmed: twoFactorConfig.sms.confirmed, maskedData: twoFactorConfig.sms.data, type: TwoFactorType.sms),
            TwoFactorItem(name: "id_call".localized, enabled: twoFactorConfig.phone.enabled, confirmed: twoFactorConfig.phone.confirmed, maskedData: twoFactorConfig.phone.data, type: TwoFactorType.phone),
            TwoFactorItem(name: "id_authenticator_app".localized, enabled: twoFactorConfig.gauth.enabled, confirmed: twoFactorConfig.gauth.confirmed, type: TwoFactorType.gauth)
        ]
    }

    private static func threshold(from twoFactorConfig: TwoFactorConfig?, settings: Settings?, gdkNetwork: GdkNetwork?) -> String {
        guard let twoFactorConfig,
              twoFactorConfig.anyEnabled,
              let settings else {
            return ""
        }
        let limits = twoFactorConfig.limits
        var (amount, den) = ("", "")
        if limits.isFiat {
            let balance = Balance.fromFiat(limits.fiat ?? "0", assetId: AssetInfo.btcId)
            (amount, den) = balance?.toDenom() ?? ("", "")
        } else {
            let denom = settings.denomination.rawValue
            let assetId = gdkNetwork?.getFeeAsset() ?? AssetInfo.btcId
            let balance = Balance.from(limits.get(TwoFactorConfigLimits.CodingKeys(rawValue: denom)!) ?? "0", assetId: assetId)
            (amount, den) = balance?.toFiat() ?? ("", "")
        }
        return String(format: "%@ %@", amount, den)
    }

    func setCsvTimeLock(csv: CsvTime) async throws {
        try await selectedBackend?.setCsvTimeLock(csv: csv)
    }
    func resetTwoFactor(email: String) async throws {
        try await selectedBackend?.resetTwoFactor(email: email, isDispute: false)
    }
    func disable(type: TwoFactorType) async throws {
        let config = TwoFactorConfigItem(enabled: false, confirmed: false, data: "")
        let params = ChangeSettingsTwoFactorParams(method: type, config: config)
        try await selectedBackend?.changeSettingsTwoFactor(params)
    }
}
