import UIKit

enum NetworkPrefs: Int, CaseIterable {
    case mainnet = 0
    case testnet = 1

    var name: String {
        switch self {
        case .mainnet:
            return "Mainnet"
        case .testnet:
            return "Testnet"
        }
    }

    var icon: UIImage {
        switch self {
        case .mainnet:
            return UIImage(named: "ic_dialog_sym_mainnet")!.maskWithColor(color: .white)
        case .testnet:
            return UIImage(named: "ic_dialog_sym_testnet")!.maskWithColor(color: .white)
        }
    }

    static func getItems() -> [DialogListCellModel] {
        var items: [DialogListCellModel] = []
        NetworkPrefs.allCases.forEach {
            items.append(DialogListCellModel(type: .list,
                                             icon: $0.icon,
                                             title: $0.name))
        }
        return items
    }
}
