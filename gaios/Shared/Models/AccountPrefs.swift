import UIKit

enum AccountPrefs: Int, CaseIterable {
    case rename = 0
    case archive
    case enhanceSecurity
    case nodeInfo
    case remove

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
            return "Node Info"
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
        }
    }

    static func getItems(isLightning: Bool) -> [DialogListCellModel] {
        var items: [DialogListCellModel] = []
        if !isLightning {
            items += [DialogListCellModel(type: .list,
                                          icon: AccountPrefs.rename.icon,
                                          title: AccountPrefs.rename.name)]
            if let subaccount = WalletManager.current?.subaccounts,
               subaccount.filter({ !$0.hidden }).count > 1 {
                items += [DialogListCellModel(type: .list,
                                              icon: AccountPrefs.archive.icon,
                                              title: AccountPrefs.archive.name)]
            }
        } else {
            items += [DialogListCellModel(type: .list,
                                          icon: AccountPrefs.nodeInfo.icon,
                                          title: AccountPrefs.nodeInfo.name)]
            items += [DialogListCellModel(type: .list,
                                          icon: AccountPrefs.remove.icon,
                                          title: AccountPrefs.remove.name)]
        }

        return items
    }
}
