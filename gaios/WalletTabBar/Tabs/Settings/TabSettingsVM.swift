import Foundation
import UIKit
import core
import gdk
import greenaddress

class TabSettingsVM: TabViewModel {
    
    var settings: [SettingSection] {
        state.settings
    }
    
    // load wallet manager for current logged session
    var session: SessionManager? { wallet.prominentSession }
    var isWatchonly: Bool { wallet.isWatchonly }
    var isEphemeral: Bool { wallet.isEphemeral }
    var isWatchonlySinglesig: Bool { (wallet.isWatchonly ?? false) && (mainAccount.username?.isEmpty ?? true) }
    var isSinglesig: Bool { session?.gdkNetwork.electrum ?? true }
    var isHW: Bool { AccountsRepository.shared.current?.isHW ?? false }
    var multiSigSession: SessionManager? { wallet.activeSessions.values.filter { !$0.gdkNetwork.electrum }.first }
    
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
                subtitle: "",
                attributed: getDenominationExchangeInfo(settings: settings, network: session.networkType),
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
                subtitle: "",
                type: .archievedAccounts)
        case .watchOnly:
            return gaios.TabSettingsCellModel(
                title: SettingsItem.watchOnly.string,
                subtitle: "",
                type: .watchOnly)
        case .twoFactorAuthication:
            return gaios.TabSettingsCellModel(
                title: SettingsItem.twoFactorAuthication.string,
                subtitle: "",
                type: .twoFactorAuthication)
        case .pgpKey:
            return gaios.TabSettingsCellModel(
                title: SettingsItem.pgpKey.string,
                subtitle: "",
                type: .pgpKey)
        case .autoLogout:
            guard let session = WalletManager.current?.prominentSession, let settings = session.settings else { return nil }
            return gaios.TabSettingsCellModel(
                title: SettingsItem.autoLogout.string,
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
                subtitle: "\(AccountsRepository.shared.current?.name ?? "")",
                type: .rename)
        case .lightning:
            return gaios.TabSettingsCellModel(
                title: SettingsItem.lightning.string,
                subtitle: "",
                type: .lightning)
        case .ampID:
            return gaios.TabSettingsCellModel(
                title: SettingsItem.ampID.string,
                subtitle: "",
                type: .ampID)
        case .createAccount:
            return gaios.TabSettingsCellModel(
                title: SettingsItem.createAccount.string,
                subtitle: "",
                type: .createAccount)
        }
    }
    
    func getDenominationExchangeInfo(settings: Settings, network: NetworkSecurityCase) -> NSMutableAttributedString {
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

    func getSubaccountsAmp() -> [WalletItem] {
        wallet.subaccounts.filter({ $0.type == .amp })
    }

    func createSubaccountAmp() async throws {
        guard let session = wallet.liquidMultisigSession else {
            throw GaError.GenericError("id_invalid_session".localized)
        }
        let wasLoggedMultisig = session.logged
        try await session.connect()
        guard session.connected else {
            throw GaError.GenericError("id_connection_failed".localized)
        }
        if let device = wallet.hwDevice {
            try await session.register(credentials: nil, hw: device)
            _ = try await session.loginUser(device)
        } else {
            if let credentials = try await wallet.prominentSession?.getCredentials(password: "") {
                try await session.register(credentials: credentials, hw: nil)
                _ = try await session.loginUser(credentials)
            }
        }
        _ = try await session.createSubaccount(CreateSubaccountParams(name: uniqueAmpName(), type: .amp))
        if !wasLoggedMultisig {
            // hide default 0 multisig subaccount when creating a new multisig
            _ = try await session.updateSubaccount(UpdateSubaccountParams(subaccount: 0, hidden: true))
        }
        _ = try await wallet.subaccounts()
    }

    func uniqueAmpName() -> String {
        let counter = wallet.subaccounts.filter({ $0.type == .amp && $0.gdkNetwork.liquid }).count
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
            forNetwork: mainAccount.keychainLightning)
    }
}
