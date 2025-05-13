import Foundation
import UIKit
import gdk
import core

class ReceiveAssetCellModel {
    var assetId: String
    var asset: AssetInfo?
    var icon: UIImage?

    init(assetId: String) {
        self.assetId = assetId
        asset = WalletManager.current?.info(for: assetId)
        icon = WalletManager.current?.image(for: assetId)
    }
}
