import Foundation
import UIKit

import core

class AssetSelectCellModel {
    var asset: AssetInfo?
    var icon: UIImage?
    var anyAmp: Bool = false
    var anyAmpLegacy: Bool = false
    var anyLiquid: Bool = false

    init(assetId: String, satoshi: Int64) {
        asset = WalletManager.current?.info(for: assetId)
        icon = WalletManager.current?.image(for: assetId)
    }
    init(anyAmp: Bool) {
        self.anyAmp = anyAmp
    }
    init(anyAmpLegacy: Bool) {
        self.anyAmpLegacy = anyAmpLegacy
    }
    init(anyLiquid: Bool) {
        self.anyLiquid = anyLiquid
    }
    func isLBTC() -> Bool {
        return asset?.assetId == AssetInfo.lbtcId
    }
}
