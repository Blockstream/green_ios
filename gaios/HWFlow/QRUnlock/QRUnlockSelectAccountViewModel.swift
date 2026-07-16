import Foundation
import UIKit
import core

import hw
import greenaddress

class QRUnlockSelectAccountViewModel {

    var assetCellModel: AssetSelectCellModel?
    var asset: String {
        didSet {
            assetCellModel = AssetSelectCellModel(assetId: asset, satoshi: 0)
        }
    }

    init(asset: String) {
        self.asset = asset
        self.assetCellModel = AssetSelectCellModel(assetId: asset, satoshi: 0)
    }

    var showAll = false

    func listBitcoin(extended: Bool) -> [PolicyCellType] {
        var list: [PolicyCellType] = [.NativeSegwit, .LegacySegwit, .Lightning, .TwoFAProtected, .TwoOfThreeWith2FA]
        if !extended {
            list = [.NativeSegwit, .Lightning, .TwoFAProtected]
        }
        if WalletManager.current?.testnet ?? false {
            list.removeAll(where: { $0 == .Lightning })
        }
        return list
    }

    func listLiquid(extended: Bool) -> [PolicyCellType] {
        var list: [PolicyCellType] = [.NativeSegwit, .LegacySegwit, .TwoFAProtected, .Amp]
        if !extended {
            list = [.NativeSegwit, .TwoFAProtected]
        }
        return list
    }

    func isAdvancedEnable() -> Bool {
        return true
    }

    /// cell models
    func getPolicyCellModels() -> [PolicyCellModel] {
        let policies = policiesForAsset(for: asset, extended: showAll)
        return policies.map { PolicyCellModel.from(policy: $0) }
    }

    func policiesForAsset(for assetId: String, extended: Bool) -> [PolicyCellType] {
        if AssetInfo.btcId == assetId { // btc
            return listBitcoin(extended: extended)
        } else { // liquid
            return listLiquid(extended: extended)
        }
    }

    func device() -> HWDevice {
        return .defaultJade(fmwVersion: nil)
    }

    func uniqueName(_ type: AccountType, liquid: Bool) -> String {
        let network = liquid ? " Liquid " : " "

        let counter = WalletManager.current?.accounts.filter {
            $0.type == type && $0.gdkNetwork.liquid == liquid
        }.count ?? 0
        if counter > 0 {
            return "\(type.string)\(network)\(counter+1)"
        }
        return "\(type.string)\(network)"
    }
}
