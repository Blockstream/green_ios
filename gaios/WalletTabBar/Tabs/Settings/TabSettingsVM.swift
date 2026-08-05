import Foundation
import UIKit
import core

import greenaddress

class TabSettingsVM: TabViewModel {

    var settings: [SettingSection] {
        state.settings
    }

    // load wallet manager for current logged session
    var session: SessionManager? { wm.prominentSession }
    var isWatchonly: Bool { wm.isWatchonly }
    var isEphemeral: Bool { wm.isEphemeral }
    var isWatchonlySinglesig: Bool { (wm.isWatchonly) && (mainWallet.username?.isEmpty ?? true) }
    var isSinglesig: Bool { session?.gdkNetwork.electrum ?? true }
    var isHW: Bool { WalletsStorage.shared.current?.isHW ?? false }
    var multiSigSession: SessionManager? {
        wm
            .multisigNetworkIds
            .compactMap { wm.gdkNetworkBackendOrNil($0) }
            .compactMap(\.session)
            .filter { $0.logged }
            .filter { !$0.gdkNetwork.electrum }.first
    }

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
            guard let session = WalletManager.current?.prominentSession, let settings = session.settings else { return nil }
            return gaios.TabSettingsCellModel(
                title: SettingsItem.unifiedDenominationExchange.string,
                icon: UIImage(named: "rightArrow"),
                subtitle: "",
                attributed: getDenominationExchangeInfo(settings: settings, network: session.networkId),
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
            guard let session = WalletManager.current?.prominentSession, let settings = session.settings else { return nil }
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

    func hasSubaccountAmp() -> Bool {
        !getSubaccountsAmp().isEmpty
    }

    func getSubaccountsAmp() -> [Account] {
        wm.accounts.filter({ $0.type == .ampAccount || $0.type == .amp2Account })
    }

    func createSubaccountAmp() async throws {
        let session = try wm.gdkNetworkBackend(
            wm.liquidMultisigNetworkId
        ).session
        let wasLoggedMultisig = session.logged
        try await session.connect()
        guard session.connected else {
            throw GaError.GenericError("id_connection_failed".localized)
        }
        if let device = wm.hwDevice {
            try await session.register(credentials: nil, hw: device)
            _ = try await session.loginUser(device)
        } else {
            if let credentials = try await wm.prominentSession?.getCredentials(password: "") {
                try await session.register(credentials: credentials, hw: nil)
                _ = try await session.loginUser(credentials)
            }
        }
        _ = try await session
            .createSubaccount(
                CreateSubaccountParams(name: uniqueAmpName(), type: .ampAccount)
            )
        if !wasLoggedMultisig {
            // hide default 0 multisig subaccount when creating a new multisig
            _ = try await session.updateSubaccount(UpdateSubaccountParams(subaccount: 0, hidden: true))
        }
        _ = try await wm.getAccounts()
    }

    func uniqueAmpName() -> String {
        let counter = wm.accounts.filter(
            { $0.type == .ampAccount && $0.gdkNetwork.liquid
            }).count
        if counter > 0 {
            return "Liquid AMP \(counter+1)"
        }
        return "Liquid AMP"
    }

    func dialogAccountsModel() -> DialogAccountsViewModel {
        return DialogAccountsViewModel(
            title: "id_account_selector".localized,
            hint: "id_select_an_account_to_get_the".localized,
            isSelectable: true,
            assetId: nil,
            accounts: getSubaccountsAmp(),
            hideBalance: false)
    }

    func hasLightning() -> Bool {
        return AuthenticationTypeHandler.findAuth(
            method: .AuthKeyLightning,
            forNetwork: mainWallet.keychainLightning)
    }

    func rescanSwaps() async throws {
        try await SwapRescanService(wm: wm).rescan()
    }

    func lTDetailsViewModel() -> LTDetailsViewModel? {
        guard let lightningSession = wm.lightningSession else { return nil }
        return LTDetailsViewModel(lightningSession: lightningSession)
    }

    func lTCreateViewModel() -> LTCreateViewModel? {
        return LTCreateViewModel(
            mainWallet: mainWallet,
            wallet: walletDataModel)
    }
}
