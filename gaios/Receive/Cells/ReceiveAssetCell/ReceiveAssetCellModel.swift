import Foundation
import UIKit
import gdk
import core

class ReceiveAssetCellModel {

    var asset: AssetInfo?
    var icon: UIImage?
    var anyOrAsset: AnyOrAsset
    var title: String?

    init(_ ref: AnyOrAsset) {
        anyOrAsset = ref
        switch ref {
        case .anyLiquid:
            title = "id_receive_any_liquid_asset".localized
            icon = UIImage(named: "default_asset_liquid_icon")!
        case .anyAmp:
            title = "id_receive_any_amp_asset".localized
            icon = UIImage(named: "default_asset_amp_icon")!
        case .asset(let assetId):
            asset = WalletManager.current?.info(for: assetId)
            icon = WalletManager.current?.image(for: assetId)
            title = asset?.name ?? assetId
        }
    }
    func isLBTC() -> Bool {
        return asset?.assetId == AssetInfo.lbtcId
    }
}
