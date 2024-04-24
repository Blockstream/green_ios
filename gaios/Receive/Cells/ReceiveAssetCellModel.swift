import Foundation
import UIKit
import gdk
import core

struct ReceiveAssetCellModel {
    let assetId: String
    let account: WalletItem

    var icon: UIImage? {
        if account.gdkNetwork.lightning {
            return UIImage(named: "ic_lightning_btc")
        } else {
            return WalletManager.current?.image(for: assetId)
        }
    }

    var assetName: String? {
        WalletManager.current?.info(for: assetId).name
    }

    var ticker: String? {
        WalletManager.current?.info(for: assetId).ticker
    }
}
