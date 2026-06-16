import Foundation
import UIKit
import core

struct AccountCellModel {
    var account: Account
    var satoshi: Int64
    var assetId: String?
    var name: String { account.localizedName }
    var lblType: String { account.type.path.uppercased() }
    var backend: AccountBackend? {
        WalletManager.current?.accountBackendOrNil(account)
    }
    var hasTxs: Bool { backend?.hasTxs ?? false }
    var networkId: NetworkId { account.networkId }
    var balanceStr: String? {
        let assetId = assetId ?? account.gdkNetwork.getFeeAsset()
        if let converted = Balance.fromSatoshi(satoshi, assetId: assetId) {
            let (amount, denom) = converted.toValue()
            return "\(amount) \(denom)"
        }
        return nil
    }
    var fiatStr: String? {
        let assetId = assetId ?? account.gdkNetwork.getFeeAsset()
        if let converted = Balance.fromSatoshi(satoshi, assetId: assetId) {
            let (amount, denom) = converted.toFiat()
            return "\(amount) \(denom)"
        }
        return nil
    }
}
