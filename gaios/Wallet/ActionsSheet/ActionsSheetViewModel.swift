import Foundation
import UIKit
import core

enum ActionsSheetType {
    case buy
    case transfer
    case scan
}

class ActionsSheetViewModel {

    func getRemoteConfigForOnOffRamps() -> Bool {
        return AnalyticsManager.shared.getRemoteConfigValue(key: AnalyticsManager.countlyRemoteConfigFeatureOnOffRamps) as? Bool ?? false
    }

    let actionBuyCellModel = ActionsSheetCellModel(title: "id_buy_btc".localized,
                                                   hint: "BTC".localized,
                                                   icon: UIImage(named: "ic_dialog_main_actions_buy")!,
                                                   type: ActionsSheetType.buy)
    let actionTransfertCellModel = ActionsSheetCellModel(title: "id_account_transfer".localized,
                                                   hint: "id_move_across_accounts".localized,
                                                   icon: UIImage(named: "ic_dialog_main_actions_transfer")!,
                                                   type: ActionsSheetType.transfer)
    let actionQRCellModel = ActionsSheetCellModel(title: "id_qr_scanner".localized,
                                                   hint: "id_scan_qr_code".localized,
                                                   icon: UIImage(named: "ic_dialog_main_actions_scan")!,
                                                   type: ActionsSheetType.scan)
    var cellModels: [ActionsSheetCellModel] {
        var actions = [ActionsSheetCellModel]()
        if getRemoteConfigForOnOffRamps() {
            actions += [actionBuyCellModel]
        }
//        if Bundle.main.dev {
//            actions += [actionTransfertCellModel]
//        }
        actions += [actionQRCellModel]
        return actions
    }
}
