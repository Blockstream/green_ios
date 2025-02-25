import Foundation

// Section of settings
enum USSection: String, Codable, CaseIterable {
    case Logout = "id_logout"
    case General = "id_general"
    case Security = "id_security"
    case Recovery = "id_recovery"
    case About = "id_about"
    case Lightning = "id_lightning"
}

enum USItem: String, Codable, CaseIterable {
    case Logout = "id_logout"
    case UnifiedDenominationExchange = "id_denomination__exchange_rate"
    case ArchievedAccounts = "id_archived_accounts"
    case WatchOnly = "id_watchonly"
    case ChangePin = "id_change_pin"
    case LoginWithBiometrics = "id_login_with_biometrics"
    case TwoFactorAuthication = "id_twofactor_authentication"
    case PgpKey = "id_pgp_key"
    case AutoLogout = "id_auto_logout_timeout"
    case BackUpRecoveryPhrase = "id_back_up_recovery_phrase"
    case Version = "id_version"
    case SupportID = "id_support"
    case GenuineCheck = "Genuine Check"

    var string: String { self.rawValue.localized }
}

struct UserSettingsItem {
    var title: String
    var subtitle: String
    var attributed: NSMutableAttributedString?
    var section: USSection
    var type: USItem
    var switcher: Bool?
}
