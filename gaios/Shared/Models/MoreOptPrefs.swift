import UIKit
import gdk

enum MoreOptPrefs: Int, CaseIterable {
    case requestAmount = 0
    case sweep = 1
    case addressAuth = 2

    var name: String {
        switch self {
        case .requestAmount:
            return "id_request_amount".localized
        case .sweep:
            return "id_sweep_from_paper_wallet".localized
        case .addressAuth:
            return "id_list_of_addresses".localized
        }
    }

    var icon: UIImage {
        switch self {
        case .requestAmount:
            return UIImage(named: "ic_dialog_arrow_down_square")!.maskWithColor(color: .white)
        case .sweep:
            return UIImage(named: "ic_dialog_sweep_wallet")!.maskWithColor(color: .white)
        case .addressAuth:
            return UIImage(named: "ic_address_auth_list")!.maskWithColor(color: .white)
        }
    }

    static func getPrefs(account: WalletItem, assetId: String) -> [MoreOptPrefs] {

        let hideSweep = account.gdkNetwork.liquid || account.gdkNetwork.lightning
        let hideSign = account.gdkNetwork.lightning
        let hideAmountRequest = account.gdkNetwork.lightning || !AssetInfo.baseIds.contains(assetId)

        var prefs: [MoreOptPrefs] = []
        if hideAmountRequest == false {
            prefs.append(.requestAmount)
        }
        if hideSweep == false {
            prefs.append(.sweep)
        }
        if hideSign == false {
            prefs.append(.addressAuth)
        }
        return prefs
    }

    static func getItems(account: WalletItem, assetId: String) -> [DialogListCellModel] {
        return MoreOptPrefs.getPrefs(account: account, assetId: assetId)
            .map {
                DialogListCellModel(
                    type: .list,
                    icon: $0.icon,
                    title: $0.name)
            }
    }
}
