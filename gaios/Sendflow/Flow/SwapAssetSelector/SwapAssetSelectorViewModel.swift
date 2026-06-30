import Foundation
import core
import UIKit

enum SwapAssetType {
    case bitcoin
    case lightning
    case liquid
    
    var title: String {
        switch self {
        case .bitcoin: "Bitcoin"
        case .lightning: "Lightning Bitcoin"
        case .liquid: "Liquid Bitcoin"
        }
    }
    
    var icon: UIImage? {
        switch self {
        case .bitcoin: WalletManager.current?.image(for: AssetInfo.btcId)
        case .lightning: UIImage(named: "ic_lightning_btc")
        case .liquid: WalletManager.current?.image(for: AssetInfo.lbtcId)
        }
    }
}

@MainActor
final class SwapAssetSelectorViewModel {
    var swapDirection: SwapPositionEnum
    
    var assetTypes: [SwapAssetType] {
        var types: [SwapAssetType] = [.bitcoin, .liquid]
        let isLightningEnabled = WalletManager.current?.hasLightning ?? false
        let hasLightningSubaccounts = !(WalletManager.current?.lightningSubaccounts.isEmpty ?? true)
        if isLightningEnabled && hasLightningSubaccounts {
            types.insert(.lightning, at: 1)
        }
        return types
    }

    init(swapDirection: SwapPositionEnum) {
        self.swapDirection = swapDirection
    }
}

