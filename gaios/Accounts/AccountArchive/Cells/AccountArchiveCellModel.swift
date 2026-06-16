import Foundation
import UIKit
import core

struct AccountArchiveCellModel {
    var account: Account
    var satoshi: Int64?
    var assetId: String?
    var name: String { account.localizedName }
    var lblType: String { account.type.path.uppercased() }
    var hasTxs: Bool { (try? account.hasTxs(WalletManager.current!)) ?? false}
    var networkId: NetworkId { account.networkId }
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
