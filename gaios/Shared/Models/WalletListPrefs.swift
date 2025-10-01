import UIKit

enum WalletListPrefs: Int, CaseIterable {
    case settings
    case about

    var name: String {
        switch self {
        case .settings:
            return "id_app_settings".localized
        case .about:
            return "About Blockstream".localized
        }
    }
    var icon: UIImage {
        switch self {
        case .settings:
            return UIImage(named: "ic_wallet_list_settings")!.maskWithColor(color: .white)
        case .about:
            return UIImage(named: "ic_wallet_list_about")!.maskWithColor(color: .white)
        }
    }
    static func getPrefs() -> [WalletListPrefs] {
        return WalletListPrefs.allCases
    }
    static func getItems() -> [DialogListCellModel] {
        var items: [DialogListCellModel] = []
        let data = getPrefs()
        data.forEach {
            items.append(DialogListCellModel(type: .list,
                                             icon: $0.icon,
                                             title: $0.name))
        }
        return items
    }
}
