import Foundation
import UIKit
import core

import greenaddress

class TabSettingsVM: TabViewModel {

    var settings: [SettingSection] {
        state.settings
    }

    // load wallet manager for current logged session
    var isWatchonly: Bool { wm.isWatchonly }
    var isEphemeral: Bool { wm.isEphemeral }
    var isWatchonlySinglesig: Bool { (wm.isWatchonly) && (mainWallet.username?.isEmpty ?? true) }
    var isHW: Bool { WalletsStorage.shared.current?.isHW ?? false }

    func getSettingsItemCellModel(for setting: SettingsItem) -> TabSettingsCellModel? {
        switch setting {
        case .header:
            return gaios.TabSettingsCellModel(
                title: "id_settings".localized,
                subtitle: "",
                type: setting)
        case .logout:
            return gaios.TabSettingsCellModel(
                title: "id_log_out".localized,
                icon: UIImage(named: "ic_logout"),
                subtitle: "",
                type: setting)
        case .unifiedDenominationExchange:
            guard let backend = wm.prominentNetworkBackend, let settings = backend.settings else { return nil }
            return gaios.TabSettingsCellModel(
                title: SettingsItem.unifiedDenominationExchange.string,
                icon: UIImage(named: "rightArrow"),
                subtitle: "",
                attributed: getDenominationExchangeInfo(settings: settings, network: backend.networkId),
                type: setting)
        case .support:
            return gaios.TabSettingsCellModel(
                title: SettingsItem.support.string,
                icon: UIImage(named: "ic_contact_support"),
                subtitle: "",
                type: .support)
        case .archievedAccounts:
            return gaios.TabSettingsCellModel(
                title: SettingsItem.archievedAccounts.string,
                icon: UIImage(named: "rightArrow"),
                subtitle: "",
                type: .archievedAccounts)
        case .watchOnly:
            return gaios.TabSettingsCellModel(
                title: SettingsItem.watchOnly.string,
                icon: UIImage(named: "rightArrow"),
                subtitle: "",
                type: .watchOnly)
        case .twoFactorAuthication:
            return gaios.TabSettingsCellModel(
                title: SettingsItem.twoFactorAuthication.string,
                icon: UIImage(named: "rightArrow"),
                subtitle: "",
                type: .twoFactorAuthication)
        case .pgpKey:
            return gaios.TabSettingsCellModel(
                title: SettingsItem.pgpKey.string,
                icon: UIImage(named: "rightArrow"),
                subtitle: "",
                type: .pgpKey)
        case .autoLogout:
            guard let settings = wm.settings else { return nil }
            return gaios.TabSettingsCellModel(
                title: SettingsItem.autoLogout.string,
                icon: UIImage(named: "rightArrow"),
                subtitle: (settings.autolock).string,
                type: .autoLogout)
        case .version:
            return gaios.TabSettingsCellModel(
                title: SettingsItem.version.string,
                subtitle: Common.versionNumber,
                type: .version)
        case .supportID:
            return gaios.TabSettingsCellModel(
                title: SettingsItem.supportID.string,
                icon: UIImage(named: "ic_copy_small"),
                subtitle: "id_copy_support_id".localized,
                type: .supportID)
        case .rename:
            return gaios.TabSettingsCellModel(
                title: "\("id_rename".localized)",
                icon: UIImage(named: "rightArrow"),
                subtitle: "\(WalletsStorage.shared.current?.name ?? "")",
                type: .rename)
        case .lightning:
            return gaios.TabSettingsCellModel(
                title: SettingsItem.lightning.string,
                icon: UIImage(named: "rightArrow"),
                subtitle: "",
                type: .lightning)
        case .ampID:
            return gaios.TabSettingsCellModel(
                title: SettingsItem.ampID.string,
                icon: UIImage(named: "rightArrow"),
                subtitle: "",
                type: .ampID)
        case .createAccount:
            return gaios.TabSettingsCellModel(
                title: SettingsItem.createAccount.string,
                icon: UIImage(named: "rightArrow"),
                subtitle: "",
                type: .createAccount)
        case .swaps:
            return gaios.TabSettingsCellModel(
                title: SettingsItem.swaps.string,
                icon: UIImage(named: "rightArrow"),
                subtitle: "",
                type: .swaps)
        case .rescanSwaps:
            return gaios.TabSettingsCellModel(
                title: SettingsItem.rescanSwaps.string,
                icon: UIImage(named: "rightArrow"),
                subtitle: "",
                type: .rescanSwaps)
        }
    }

    func getDenominationExchangeInfo(settings: Settings, network: NetworkId) -> NSMutableAttributedString {
        let den = settings.denomination.string(for: network.gdkNetwork)
        let pricing = settings.pricing["currency"] ?? ""
        let exchange = (settings.pricing["exchange"] ?? "").uppercased()
        let plain = "Display values in \(den) and exchange rate in \(pricing) using \(exchange)"
        let iAttr: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.gAccent()
        ]
        let attrStr = NSMutableAttributedString(string: plain)
        attrStr.setAttributes(iAttr, for: den)
        attrStr.setAttributes(iAttr, for: pricing)
        attrStr.setAttributes(iAttr, for: exchange)
        return attrStr
    }

    func rescanSwaps() async throws {
        try await SwapRescanService(wm: wm).rescan()
    }
}
