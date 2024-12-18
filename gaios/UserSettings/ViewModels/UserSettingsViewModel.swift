import Foundation
import UIKit
import core
import gdk

class UserSettingsViewModel {

    // load wallet manager for current logged session
    var wm: WalletManager? { WalletManager.current }

    // load wallet manager for current logged session
    var session: SessionManager? { wm?.prominentSession }
    var settings: Settings? { session?.settings }
    var isWatchonly: Bool { wm?.account.isWatchonly ?? false }
    var isSinglesig: Bool { session?.gdkNetwork.electrum ?? true }
    var isHW: Bool { wm?.account.isHW ?? false }
    var isDerivedLightning: Bool { wm?.account.isDerivedLightning ?? false }
    var multiSigSession: SessionManager? { wm?.activeSessions.values.filter { !$0.gdkNetwork.electrum }.first }

    // reload all contents
    var reloadTableView: (() -> Void)?

    // settings cell models
    var sections = [USSection]()
    var items = [USSection: [UserSettingsItem]]()
    var cellModels = [USSection: [UserSettingsCellModel]]() {
        didSet {
            reloadTableView?()
        }
    }

    func getCellModel(at indexPath: IndexPath) -> UserSettingsCellModel? {
        let section = sections[indexPath.section]
        return cellModels[section]?[indexPath.row]
    }

    func getCellModelsForSection(at indexSection: Int) -> [UserSettingsCellModel]? {
        let section = sections[indexSection]
        return cellModels[section]
    }

    func getAbout() -> [UserSettingsItem] {
        let version = UserSettingsItem(
            title: USItem.Version.string,
            subtitle: Common.versionString,
            section: .About,
            type: .Version)
        let support = UserSettingsItem(
            title: USItem.SupportID.string,
            subtitle: "id_copy_support_id".localized,
            section: .About,
            type: .SupportID)
        if multiSigSession != nil {
            return [version, support]
        }
        return [version]
    }

    func getSecurity() -> [UserSettingsItem] {
        let changePin = UserSettingsItem(
            title: USItem.ChangePin.string,
            subtitle: "",
            section: .Security,
            type: .ChangePin)
        let bioTitle = AuthenticationTypeHandler.supportsBiometricAuthentication() ? NSLocalizedString(AuthenticationTypeHandler.biometryType == .faceID ? "id_face_id" : "id_touch_id", comment: "") : NSLocalizedString("id_touchface_id_not_available", comment: "")
        var bioSwitch: Bool?
        if AuthenticationTypeHandler.supportsBiometricAuthentication(), let keychain = wm?.account.keychain {
            bioSwitch = AuthenticationTypeHandler.findAuth(method: .AuthKeyBiometric, forNetwork: keychain)
        }
        let loginWithBiometrics = UserSettingsItem(
            title: bioTitle,
            subtitle: "",
            section: .Security,
            type: .LoginWithBiometrics,
            switcher: bioSwitch
        )
        let twoFactorAuth = UserSettingsItem(
            title: USItem.TwoFactorAuthication.string,
            subtitle: "",
            section: .Security,
            type: .TwoFactorAuthication)
        let pgpKey = UserSettingsItem(
            title: USItem.PgpKey.string,
            subtitle: "",
            section: .Security,
            type: .PgpKey)
        let autolock = UserSettingsItem(
            title: USItem.AutoLogout.string,
            subtitle: (settings?.autolock ?? .fiveMinutes).string,
            section: .Security,
            type: .AutoLogout)
        let genuineCheck = UserSettingsItem(
            title: USItem.GenuineCheck.string,
            subtitle: "Verify the authenticity of your Jade.".localized,
            section: .Security,
            type: .GenuineCheck)
        var menu = [UserSettingsItem]()
        if !isWatchonly && !isHW {
            menu += [changePin, loginWithBiometrics]
        }
        if !isWatchonly && wm?.hasMultisig ?? false {
            menu += [twoFactorAuth, pgpKey]
        }
        menu += [autolock]
        if !isWatchonly && showGenuineCheck() {
            menu += [genuineCheck]
        }
        return menu
    }
    
    func showGenuineCheck() -> Bool {
        if isHW && BleViewModel.shared.isConnected() {
            if let version = BleViewModel.shared.jade?.version, version.boardType == .v2 {
                return true
            }
        }
        return false
    }

    func getGeneral() -> [UserSettingsItem] {
        guard let settings = settings, let session = session else { return [] }
        let network: NetworkSecurityCase = session.gdkNetwork.mainnet ? .bitcoinSS : .testnetSS
        let unifiedDenominationExchange = UserSettingsItem(
            title: USItem.UnifiedDenominationExchange.string,
            subtitle: "",
            attributed: getDenominationExchangeInfo(settings: settings, network: network),
            section: .General,
            type: .UnifiedDenominationExchange)
//        let archievedAccounts = UserSettingsItem(
//            title: USItem.ArchievedAccounts.string,
//            subtitle: "",
//            section: .General,
//            type: .ArchievedAccounts)
        let watchOnly = UserSettingsItem(
            title: USItem.WatchOnly.string,
            subtitle: "",
            section: .General,
            type: .WatchOnly)
        if isDerivedLightning || isWatchonly {
            return [unifiedDenominationExchange]
        }
        return [unifiedDenominationExchange /*, archievedAccounts*/, watchOnly]
    }

    func getRecovery() -> [UserSettingsItem] {
        let recovery = UserSettingsItem(
            title: USItem.BackUpRecoveryPhrase.string,
            subtitle: "id_touch_to_display".localized,
            section: .Recovery,
            type: .BackUpRecoveryPhrase)
        if isHW {
            return []
        } else if wm?.hasMultisig ?? false {
            return [recovery]
        } else {
            return [recovery]
        }
    }

    func getLogout() -> [UserSettingsItem] {
        let logout = UserSettingsItem(
            title: wm?.account.name.localizedCapitalized ?? "",
            subtitle: "id_log_out".localized,
            section: .Logout,
            type: .Logout)
        return [logout]
    }

    func load() {
        if isDerivedLightning {
            sections = [ .Logout, .General, .About ]
            items = [ .Logout: getLogout(), .General: getGeneral(), .About: getAbout()]
        } else if isWatchonly || isHW {
            sections = [ .Logout, .General, .Security, .About ]
            items = [ .Logout: getLogout(), .General: getGeneral(), .Security: getSecurity(), .About: getAbout()]
        } else {
            sections = [ .Logout, .General, .Security, .Recovery, .About ]
            items = [
                .Logout: getLogout(),
                .General: getGeneral(),
                .Security: getSecurity(),
                .Recovery: getRecovery(),
                .About: getAbout()]
        }
        cellModels = items.mapValues { $0.map { UserSettingsCellModel($0) } }
    }

    func getDenominationExchangeInfo(settings: Settings, network: NetworkSecurityCase) -> NSMutableAttributedString {
        let den = settings.denomination.string(for: network.gdkNetwork)
        let pricing = settings.pricing["currency"] ?? ""
        let exchange = (settings.pricing["exchange"] ?? "").uppercased()
        let plain = "Display values in \(den) and exchange rate in \(pricing) using \(exchange)"
        let iAttr: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.7)
        ]
        let attrStr = NSMutableAttributedString(string: plain)
        attrStr.setAttributes(iAttr, for: den)
        attrStr.setAttributes(iAttr, for: pricing)
        attrStr.setAttributes(iAttr, for: exchange)
        return attrStr
    }
}
