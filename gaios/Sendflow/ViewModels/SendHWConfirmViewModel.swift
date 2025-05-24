import Foundation
import gdk
import core

struct SendHWConfirmViewModel {

    var isLedger = false
    var tx: Transaction
    var denomination: DenominationType
    var subaccount: WalletItem?
    var isMultiAddressees: Bool = false

    var session: SessionManager? { subaccount?.session }

    var addressee: Addressee? { tx.addressees.first }
    var address: String? { addressee?.address }
    var assetId: String { addressee?.assetId ?? tx.subaccount?.gdkNetwork.getFeeAsset() ??  "btc" }
    var sendAll: Bool { addressee?.isGreedy ?? false}
    var satoshi: Int64? { addressee?.satoshi }
    var fee: Balance? { Balance.fromSatoshi(tx.fee ?? 0, assetId: tx.subaccount?.gdkNetwork.getFeeAsset() ?? "btc") }
    var amount: Balance? { Balance.fromSatoshi(satoshi ?? 0, assetId: assetId) }
    var total: Balance? {
        let feeAsset = tx.subaccount?.gdkNetwork.getFeeAsset()
        var amount = satoshi ?? 0
        if feeAsset == assetId {
            amount += Int64(tx.fee ?? 0)
        }
        return Balance.fromSatoshi(amount, assetId: assetId)
    }
    var feeText: String? { fee?.toText(denomination) }
    var amountText: String? { amount?.toText(denomination) }
    var totalText: String? { total?.toText(denomination) }
    var totalFiatText: String? { total?.toFiatText() }
}
