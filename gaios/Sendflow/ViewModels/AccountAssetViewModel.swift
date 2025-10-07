import Foundation
import UIKit
import core
import gdk
import greenaddress

class AccountAssetViewModel {

    let accounts: [WalletItem]
    let funded: Bool
    let showBalance: Bool
    var createTx: CreateTx?
    var showAssets: Bool
    var accountAssetCellModels: [AccountAssetCellModel] = []
    var wm: WalletManager? { WalletManager.current }

    init(accounts: [WalletItem], createTx: CreateTx?, funded: Bool, showBalance: Bool, showAssets: Bool) {
        self.createTx = createTx
        self.accounts = accounts
        self.funded = funded
        self.showBalance = showBalance
        self.showAssets = showAssets
        load()
    }

    func load() {
        var models: [AccountAssetCellModel] = []
        for subaccount in accounts {
            let satoshi = subaccount.satoshi ?? [:]
            for sat in satoshi {
                var balance = [String: Int64]()
                balance[sat.0] = sat.1
                for id in balance.keys {
                    let asset = wm?.info(for: id)
                    let assetBalance = balance.filter { $0.key == asset!.assetId }
                    let satoshi = assetBalance.first?.value ?? 0
                    let isBaseAsset = createTx?.assetId == nil || AssetInfo.baseIds.contains((id ?? subaccount.gdkNetwork.getFeeAssetOrNull()) ?? "btc")
                    if let assetId = createTx?.assetId, createTx?.bip21 ?? false && assetId != id {
                    } else if !showAssets && !isBaseAsset {
                    } else if satoshi > 0 || !funded {
                        models.append(AccountAssetCellModel(account: subaccount,
                                                            asset: asset!,
                                                            balance: assetBalance,
                                                            showBalance: showBalance)
                                      )
                    }
                }
            }
        }
        self.accountAssetCellModels = models.sorted()
    }

    func select(cell: AccountAssetCellModel) {
        createTx?.subaccount = cell.account
        if createTx?.isLiquid ?? false {
            createTx?.assetId = cell.asset.assetId
        }
    }

}
