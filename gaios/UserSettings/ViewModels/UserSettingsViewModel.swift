import Foundation
import UIKit
import PromiseKit

class UserSettingsViewModel {

    // load wallet manager for current logged session
    var wm: WalletManager { WalletManager.current! }

    // load wallet manager for current logged session
    var session: SessionManager? { wm.prominentSession }
    var settings: Settings? { session?.settings }
    var isWatchonly: Bool { AccountsManager.shared.current?.isWatchonly ?? false }
    var isHW: Bool { AccountsManager.shared.current?.isHW ?? false }

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
        let versionSubtitle = String(format: NSLocalizedString("id_version_1s", comment: ""), Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? CVarArg ?? "")
        let version = UserSettingsItem(
            title: USItem.Version.string,
            subtitle: versionSubtitle,
            section: .About,
            type: .Version)
        let support = UserSettingsItem(
            title: USItem.SupportID.string,
            subtitle: "Copy support ID",
            section: .About,
            type: .SupportID)
        return [version, support]
    }

    func getSecurity() -> [UserSettingsItem] {
        let changePin = UserSettingsItem(
            title: USItem.ChangePin.string,
            subtitle: "",
            section: .Security,
            type: .ChangePin)
        let bioTitle = AuthenticationTypeHandler.supportsBiometricAuthentication() ? NSLocalizedString(AuthenticationTypeHandler.biometryType == .faceID ? "id_face_id" : "id_touch_id", comment: "") : NSLocalizedString("id_touchface_id_not_available", comment: "")
        var bioSwitch: Bool?
        if AuthenticationTypeHandler.supportsBiometricAuthentication() {
            let account = AccountsManager.shared.current
            bioSwitch = AuthenticationTypeHandler.findAuth(method: .AuthKeyBiometric, forNetwork: account?.keychain ?? "")
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
        if isHW {
            return [twoFactorAuth, pgpKey, autolock]
        } else if wm.hasMultisig {
            return [changePin, loginWithBiometrics, twoFactorAuth, pgpKey, autolock]
        } else {
            return [changePin, loginWithBiometrics, autolock]
        }
    }

    func getGeneral() -> [UserSettingsItem] {
        guard let settings = settings, let session = session else { return [] }
        let network: NetworkSecurityCase = session.gdkNetwork.mainnet ? .bitcoinSS : .testnetSS
        let bitcoinDenomination = UserSettingsItem(
            title: USItem.BitcoinDenomination.string,
            subtitle: settings.denomination.string(for: network.gdkNetwork!),
            section: .General,
            type: .BitcoinDenomination)
        let referenceExchangeRate = UserSettingsItem(
            title: USItem.ReferenceExchangeRate.string,
            subtitle: "\(settings.pricing["currency"]!)/\(settings.pricing["exchange"]!.capitalized)",
            section: .General,
            type: .ReferenceExchangeRate)
        let archievedAccounts = UserSettingsItem(
            title: USItem.ArchievedAccounts.string,
            subtitle: "",
            section: .General,
            type: .ArchievedAccounts)
        let watchOnly = UserSettingsItem(
            title: USItem.WatchOnly.string,
            subtitle: "",
            section: .General,
            type: .WatchOnly)
        return [bitcoinDenomination, referenceExchangeRate, archievedAccounts, watchOnly]
    }

    func getRecovery() -> [UserSettingsItem] {
        let recovery = UserSettingsItem(
            title: USItem.BackUpRecoveryPhrase.string,
            subtitle: "id_touch_to_display".localized,
            section: .Recovery,
            type: .BackUpRecoveryPhrase)
        let recoveryTxs = UserSettingsItem(
            title: USItem.RecoveryTransactions.string,
            subtitle: "id_legacy_script_coins".localized,
            section: .Recovery,
            type: .RecoveryTransactions)
        if isHW {
            return [recoveryTxs]
        } else if wm.hasMultisig {
            return [recovery, recoveryTxs]
        } else {
            return [recovery]
        }
    }

    func getLogout() -> [UserSettingsItem] {
        let wallet = AccountsManager.shared.current
        let logout = UserSettingsItem(
            title: (wallet?.name ?? "").localizedCapitalized,
            subtitle: NSLocalizedString("id_log_out", comment: ""),
            section: .Logout,
            type: .Logout)
        return [logout]
    }

    func load() {
        sections = [ .Logout, .General, .Security, .Recovery, .About ]
        items = [
            .Logout: getLogout(),
            .General: getGeneral(),
            .Security: getSecurity(),
            .Recovery: getRecovery(),
            .About: getAbout()]
        if isWatchonly {
            sections = [ .Logout, .About ]
            items = [ .Logout: getLogout(), .About: getAbout()]
        }
        cellModels = items.mapValues { $0.map { UserSettingsCellModel($0) } }
    }
}
