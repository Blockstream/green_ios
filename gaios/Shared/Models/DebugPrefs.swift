import UIKit

enum DebugPrefs: Int, CaseIterable {
    case deviceId = 0
    case promos = 1
    case cleanup = 2

    var name: String {
        switch self {
        case .deviceId:
            return "Copy Device ID"
        case .promos:
            return "Clear Dismissed Promos"
        case .cleanup:
            return "Clear Wallets List"
        }
    }

    var icon: UIImage {
        switch self {
        case .deviceId:
            return UIImage(named: "ic_clipboard")!.maskWithColor(color: .white)
        case .promos:
            return UIImage(named: "ic_dialog_remove")!.maskWithColor(color: .white)
        case .cleanup:
            return UIImage(named: "ic_dialog_remove")!.maskWithColor(color: .white)
        }
    }

    static func getItems() -> [DialogListCellModel] {
        var items: [DialogListCellModel] = []
        DebugPrefs.allCases.forEach {
            items.append(DialogListCellModel(type: .list,
                                             icon: $0.icon,
                                             title: $0.name))
        }
        return items
    }
}
