import UIKit

enum AccountPrefs {
    
    case rename
    case archive
    case enhanceSecurity
    case nodeInfo
    case remove
    case shortcut(state: Bool?)
    case logout

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
            return "Node Info".localized
        case .shortcut:
            return "Lightning shortcut".localized
        case .logout:
            return "id_logout".localized
        }
    }

    var hint: String? {
        switch self {
        case .shortcut:
            return "Quickly access your funds on Lightning, separately from the rest of the accounts."
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
        case .shortcut:
            return UIImage(named: "ic_lightning_shortcut_mini")!
        case .logout:
            return UIImage(named: "ic_logout")!
        }
    }
    var switchState: Bool? {
        switch self {
        case .shortcut(let state):
            return state
        default:
            return nil
        }
    }
    static func getPrefs(isEphemeral: Bool,
                         isHW: Bool,
                         isLightning: Bool,
                         isLightningShortcut: Bool,
                         switchState: Bool? = nil) -> [AccountPrefs] {
        var prefs: [AccountPrefs] = []
        if isLightningShortcut {
            prefs.append(.logout)
        } else if !isLightning {
            prefs.append(.rename)
            if let subaccount = WalletManager.current?.subaccounts,
               subaccount.filter({ !$0.hidden }).count > 1 {
                prefs.append(.archive)
            }
        } else {
            prefs.append(.nodeInfo)
            prefs.append(.remove)
            if !isEphemeral && !isHW {
                prefs.append(.shortcut(state: switchState))
            }
        }
        return prefs
    }

    static func getItems(isEphemeral: Bool,
                         isHW: Bool,
                         isLightning: Bool,
                         isLightningShortcut: Bool,
                         switchState: Bool?) -> [DialogListCellModel] {
        
        return AccountPrefs.getPrefs(
            isEphemeral: isEphemeral,
            isHW: isHW,
            isLightning: isLightning,
            isLightningShortcut: isLightningShortcut,
            switchState: switchState).map {
            DialogListCellModel(type: .list,
                                icon: $0.icon,
                                title: $0.name,
                                hint: $0.hint,
                                switchState: $0.switchState) }
    }
}
