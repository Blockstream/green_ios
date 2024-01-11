import Foundation
import UIKit

import gdk
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
        if !AppSettings.shared.experimental {
            list.removeAll(where: { $0 == .Lightning })
        }
        return list
    }

    func listLiquid(extended: Bool) -> [PolicyCellType] {
        var list:  [PolicyCellType] = [.NativeSegwit, .LegacySegwit, .TwoFAProtected, .Amp]
        if !extended {
            list = [.NativeSegwit, .TwoFAProtected]
        }
        return list
    }
    
    func isAdvancedEnable() -> Bool {
        return true
//        if asset?.amp ?? false {
//            return false
//        } else {
//            return true
//        }
    }

    /// cell models
    func getPolicyCellModels() -> [PolicyCellModel] {
        let policies = policiesForAsset(for: asset, extended: showAll)
        return policies.map { PolicyCellModel.from(policy: $0) }
    }

    func policiesForAsset(for assetId: String, extended: Bool) -> [PolicyCellType] {
//        if asset?.amp ?? false { // amp liquid asset
//            return [.Amp]
//        } else 
        if AssetInfo.btcId == assetId { // btc
            return listBitcoin(extended: extended)
        } else { // liquid
            return listLiquid(extended: extended)
        }
    }

    func device() -> HWDevice {
        return .defaultJade(fmwVersion: nil)
        //wm.account.isJade ? .defaultJade(fmwVersion: nil) : .defaultLedger()
    }

    func uniqueName(_ type: AccountType, liquid: Bool) -> String {
        return "TODO"
//        let network = liquid ? " Liquid " : " "
//        let counter = wm.subaccounts.filter { $0.type == type && $0.gdkNetwork.liquid == liquid }.count
//        if counter > 0 {
//            return "\(type.string)\(network)\(counter+1)"
//        }
//        return "\(type.string)\(network)"
    }
}
