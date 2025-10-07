import Foundation
import UIKit
import gdk
import core

class AssetSelectCellModel {
    var asset: AssetInfo?
    var icon: UIImage?
    var anyAmp: Bool = false
    var anyLiquid: Bool = false

    init(assetId: String, satoshi: Int64) {
        asset = WalletManager.current?.info(for: assetId)
        icon = WalletManager.current?.image(for: assetId)
    }
    init(anyAmp: Bool) {
        self.anyAmp = anyAmp
    }
    init(anyLiquid: Bool) {
        self.anyLiquid = anyLiquid
    }
    init(section: AssetExpandableSection) {
        switch section {
        case .anyLiquid:
            anyLiquid = true
        case .anyAmp:
            anyAmp = true
        case .asset(let assetId):
            asset = WalletManager.current?.info(for: assetId)
            icon = WalletManager.current?.image(for: assetId)
        case .none:
            break
        }
    }
    func isLBTC() -> Bool {
        return asset?.assetId == AssetInfo.lbtcId
    }
}
