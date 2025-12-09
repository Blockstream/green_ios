import Foundation
import UIKit
import gdk
import core

class ReceiveAssetCellModel {
    var assetId: String?
    var asset: AssetInfo?
    var icon: UIImage?
    var anyAsset: AnyAssetType?
    var title: String?

    init(assetId: String?, anyAsset: AnyAssetType?) {
        self.assetId = assetId
        self.anyAsset = anyAsset
        switch anyAsset {
        case .liquid:
            title = "id_receive_any_liquid_asset".localized
            icon = UIImage(named: "default_asset_liquid_icon")!
        case .amp:
            title = "id_receive_any_amp_asset".localized
            icon = UIImage(named: "default_asset_amp_icon")!
        case .none:
            if let assetId = assetId {
                asset = WalletManager.current?.info(for: assetId)
                icon = WalletManager.current?.image(for: assetId)
                title = asset?.name ?? assetId
            } else {
                title = assetId
            }
        }
    }
    func isLBTC() -> Bool {
        return asset?.assetId == AssetInfo.lbtcId
    }
}
