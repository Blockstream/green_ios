import UIKit
import core

enum AccountPrefs {

    case rename
    case archive
    case enhanceSecurity
    case nodeInfo
    case remove
    case background
    case logout
    case settings

    var name: String {
        switch self {
        case .remove:
            return "id_remove".localized
        case .rename:
            return "id_rename".localized
        case .archive:
            return "id_archive".localized
        case .enhanceSecurity:
            return "id_enhance_security".localized
        case .nodeInfo:
            return "id_node_info".localized
        case .background:
            return "Enable background payment".localized
        case .logout:
            return "id_logout".localized
        case .settings:
            return "id_settings".localized
        }
    }

    var hint: String? {
        switch self {
        case .background:
            return "You can receive payment as long as your device connected to the internet"
        default:
            return nil
        }
    }

    var icon: UIImage {
        switch self {
        case .rename:
            return UIImage(named: "ic_dialog_text_Aa")!
        case .archive:
            return UIImage(named: "ic_dialog_arrow_down")!
        case .enhanceSecurity:
            return UIImage(named: "ic_dialog_shield_check")!
        case .nodeInfo:
            return UIImage(named: "ic_lightning_plain")!
        case .remove:
            return UIImage(named: "ic_dialog_arrow_down")!
        case .background:
            return UIImage(named: "ic_lightning_shortcut_mini")!
        case .logout:
            return UIImage(named: "ic_logout")!
        case .settings:
            return UIImage(named: "ic_dialog_gear_six")!
        }
    }
    static func getPrefs(isEphemeral: Bool,
                         isHW: Bool,
                         isLightning: Bool) async -> [AccountPrefs] {
        var prefs: [AccountPrefs] = []
        if !isLightning {
            prefs.append(.rename)
            if let subaccount = WalletManager.current?.subaccounts,
               subaccount.filter({ !$0.hidden }).count > 1 {
                prefs.append(.archive)
            }
        } else {
            prefs.append(.nodeInfo)
            prefs.append(.remove)
            if !(await AccountPrefs.authorizeStatus()) {
                prefs.append(.background)
            }
        }
        return prefs
    }

    static func authorizeStatus() async -> Bool {
        await withCheckedContinuation { continuation in
            let center = UNUserNotificationCenter.current()
            center.getNotificationSettings { (settings) in
                if(settings.authorizationStatus == .authorized) {
                    continuation.resume(with: .success(true))
                    print("Push notification is enabled")
                } else {
                    continuation.resume(with: .success(false))
                    print("Push notification is not enabled")
                }
            }
        }
    }

    static func getItems(isEphemeral: Bool,
                         isHW: Bool,
                         isLightning: Bool) async -> [DialogListCellModel] {

        return await AccountPrefs.getPrefs(
            isEphemeral: isEphemeral,
            isHW: isHW,
            isLightning: isLightning).map {
            DialogListCellModel(type: .list,
                                icon: $0.icon,
                                title: $0.name,
                                hint: $0.hint,
                                switchState: $0 == .background ? false : nil) }
    }
}
