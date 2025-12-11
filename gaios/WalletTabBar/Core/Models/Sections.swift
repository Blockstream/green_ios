import Foundation

enum SettingsItem: String, Codable, CaseIterable {
    case header = "id_header"
    case logout = "id_logout"
    case unifiedDenominationExchange = "id_denomination__exchange_rate"
    case support = "id_get_support"
    case archievedAccounts = "id_archived_accounts"
    case watchOnly = "Wallet Details"
    case twoFactorAuthication = "id_twofactor_authentication"
    case pgpKey = "id_pgp_key"
    case autoLogout = "id_auto_logout_timeout"
    case version = "id_version"
    case supportID = "Support ID"
    case rename = "id_rename_wallet"
    case lightning = "id_lightning"
    case ampID = "id_amp_id"
    case createAccount = "id_create_account"

    var string: String { self.rawValue.localized }
}

struct SettingSection: Sendable {
    let section: TabSettingsSection
    let items: [SettingsItem]
}

struct SecuritySection: Sendable {
    let section: TabSecuritySection
    let items: [PreferenceType]
}
