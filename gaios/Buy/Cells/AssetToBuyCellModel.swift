import Foundation
import UIKit
import gdk
import core

class AssetToBuyCellModel {
    var assetId: String
    var asset: AssetInfo?
    var icon: UIImage?
    var value: String?

    init(assetId: String) {
        self.assetId = assetId
        load()
    }

    func load() {
        asset = WalletManager.current?.info(for: assetId)
        icon = WalletManager.current?.image(for: assetId)
    }
}
