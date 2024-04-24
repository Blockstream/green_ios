import Foundation
import UIKit
import gdk
import core

enum AssetExpandableSection: Equatable {
    case anyLiquid
    case anyAmp
    case asset(String)
    case none
}

class AssetExpandableSelectViewModel {

    private var enableAnyLiquidAsset: Bool
    private var enableAnyAmpAsset: Bool
    private var hideLiquid: Bool
    private var hideBtc: Bool
    private let wm = WalletManager.current
    var assets: AssetAmountList
    var accountSelectSubCellModels: [AccountSelectSubCellModel] = []
    var assetSelectCellModels: [AssetSelectCellModel] = []
    var assetSelectCellModelsFilter: [AssetSelectCellModel] = []
    var selected: AssetExpandableSection = .none
    var sections: [AssetExpandableSection] = []

    init(enableAnyLiquidAsset: Bool, enableAnyAmpAsset: Bool, hideLiquid: Bool, hideBtc: Bool) {
        self.assets = AssetAmountList.from(assetIds: [])
        self.enableAnyLiquidAsset = enableAnyLiquidAsset
        self.enableAnyAmpAsset = enableAnyAmpAsset
        self.hideLiquid = hideLiquid
        self.hideBtc = hideBtc
        loadAssets()
    }

    func loadAssets() {
        var allAssets = wm?.registry.all ?? []
        if hideLiquid {
            allAssets.removeAll { $0.assetId != AssetInfo.btcId }
        } else if hideBtc {
            allAssets.removeAll { $0.assetId == AssetInfo.btcId }
        }
        assets = AssetAmountList.from(assetIds: allAssets.map { $0.assetId })
        sections = assets.amounts.compactMap { AssetExpandableSection.asset($0.0) }
        if !hideLiquid && enableAnyLiquidAsset {
            sections += [AssetExpandableSection.anyLiquid]
        }
        if !hideLiquid && enableAnyAmpAsset {
            sections += [AssetExpandableSection.anyAmp]
        }
        assetSelectCellModels = sections.map { AssetSelectCellModel(section: $0) }
        assetSelectCellModelsFilter = assetSelectCellModels
    }

    func getSection(index: Int) -> AssetExpandableSection {
        if index < 0 {
            return .none
        } else if assetSelectCellModelsFilter.count == 0 {
            return .none
        } else {
            return sections[index]
        }
    }

    func anyAssetTypes() -> [AnyAssetType] {
        var data: [AnyAssetType] = []
        if enableAnyLiquidAsset == true { data.append(.liquid) }
        if enableAnyAmpAsset == true { data.append(.amp) }
        return data
    }

    func search(_ txt: String?) {
        assetSelectCellModelsFilter = []
        assetSelectCellModels.forEach {
            if let txt = txt?.lowercased(), txt.count > 0 {
                if let asset = $0.asset,
                   (asset.name?.lowercased() ?? "").contains(txt) ||
                   (asset.ticker?.lowercased() ?? "").contains(txt) ||
                   asset.assetId.lowercased().contains(txt) {
                    self.assetSelectCellModelsFilter.append($0)
                }
            } else {
                self.assetSelectCellModelsFilter.append($0)
            }
        }
    }

    func loadAccounts(_ selected: AssetExpandableSection) {
        var accounts = wm?.subaccounts.filter { !$0.hidden } ?? []
        switch selected {
        case .anyAmp:
            accounts.removeAll { $0.type != .amp }
        case .anyLiquid:
            accounts.removeAll { !$0.gdkNetwork.liquid }
        case .asset(let assetId):
            accounts = getAccountsForAsset(assetId)
        case .none:
            accountSelectSubCellModels = []
        }
        accountSelectSubCellModels = accounts.map { AccountSelectSubCellModel(account: $0) }
    }

    func getAccountsForAsset(_ assetId: String = AssetInfo.btcId) -> [WalletItem] {
        var accounts = wm?.subaccounts.filter { !$0.hidden } ?? []
        if [AssetInfo.btcId, AssetInfo.testId].contains(assetId) {
            // for btc / test btc only
            accounts.removeAll { $0.gdkNetwork.liquid }
        } else {
            // for liquid
            accounts.removeAll { !$0.gdkNetwork.liquid }
            if let asseInfo = wm?.info(for: assetId), asseInfo.amp ?? false {
                // for liquid amp
                accounts.removeAll { $0.type != .amp }
            }
        }
        return accounts
    }
}
