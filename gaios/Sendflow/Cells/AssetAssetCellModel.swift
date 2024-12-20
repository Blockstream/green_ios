import Foundation
import UIKit
import gdk
import core

class AccountAssetCellModel: Comparable {

    var account: WalletItem
    var asset: AssetInfo
    var balance: [String: Int64]
    var showBalance: Bool

    init(account: WalletItem, asset: AssetInfo, balance: [String: Int64], showBalance: Bool) {
        self.account = account
        self.asset = asset
        self.balance = balance
        self.showBalance = showBalance
    }

    var icon: UIImage? {
        if account.gdkNetwork.lightning {
            return UIImage(named: "ic_lightning_btc")
        } else {
            return WalletManager.current?.image(for: asset.assetId)
        }
    }

    var ticker: String {
        asset.ticker ?? ""
    }

    static func == (lhs: AccountAssetCellModel, rhs: AccountAssetCellModel) -> Bool {
        lhs.account == rhs.account && lhs.asset == rhs.asset && lhs.balance == rhs.balance
    }

    static func < (lhs: AccountAssetCellModel, rhs: AccountAssetCellModel) -> Bool {
        if lhs.asset.assetId != rhs.asset.assetId {
            return WalletManager.current?.registry.sortAssets(lhs: lhs.asset.assetId, rhs: rhs.asset.assetId) ?? false
        }
        if lhs.account != rhs.account {
            return lhs.account < rhs.account
        }
        return lhs.balance[lhs.asset.assetId] ?? 0 < rhs.balance[rhs.asset.assetId] ?? 0
    }
}
