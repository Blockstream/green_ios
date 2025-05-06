import Foundation
import UIKit
import gdk
import core

class WalletAssetCellModel {
    var assetId: String
    var satoshi: Int64
    var asset: AssetInfo?
    var icon: UIImage?
    var value: String?
    var fiat: String?
    var masked: Bool = false
    var hidden: Bool = false

    init(assetId: String, satoshi: Int64, masked: Bool, hidden: Bool) {
        self.assetId = assetId
        self.satoshi = satoshi
        self.masked = masked
        self.hidden = hidden
        load()
    }

    func load() {
        asset = WalletManager.current?.info(for: assetId)
        icon = WalletManager.current?.image(for: assetId)

        if let balance = Balance.fromSatoshi(satoshi, assetId: assetId)?.toValue() {
            self.value = "\(balance.0) \(balance.1)"
        }
        if let balance = Balance.fromSatoshi(satoshi, assetId: assetId)?.toFiat() {
            self.fiat = "\(balance.0) \(balance.1)"
        }
    }
}
