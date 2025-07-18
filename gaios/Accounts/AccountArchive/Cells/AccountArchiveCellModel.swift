import Foundation
import UIKit
import gdk

struct AccountArchiveCellModel {
    var account: WalletItem
    var satoshi: Int64?
    var assetId: String?
    var name: String { account.localizedName }
    var lblType: String { account.type.path.uppercased() }
    var hasTxs: Bool { account.hasTxs }
    var networkType: NetworkSecurityCase { account.networkType }
    var balanceStr: String? {
        let assetId = assetId ?? account.gdkNetwork.getFeeAsset()
        if let satoshi = satoshi, let converted = Balance.fromSatoshi(satoshi, assetId: assetId) {
            let (amount, denom) = converted.toValue()
            return "\(amount) \(denom)"
        }
        return nil
    }
    var fiatStr: String? {
        let assetId = assetId ?? account.gdkNetwork.getFeeAsset()
        if let satoshi = satoshi, let converted = Balance.fromSatoshi(satoshi, assetId: assetId) {
            let (amount, denom) = converted.toFiat()
            return "\(amount) \(denom)"
        }
        return nil
    }
}

