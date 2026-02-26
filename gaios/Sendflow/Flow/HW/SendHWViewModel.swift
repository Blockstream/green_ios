import Foundation
import UIKit
import gdk
import core

struct SendHWViewModel {

    let isLedger = false
    let tx: Transaction
    let draft: TransactionDraft?
    let denomination: DenominationType
    let subaccount: WalletItem?
    let isMultiAddressees: Bool
    let isQRMode: Bool

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
    var deviceImage: UIImage? {
        if isLedger {
            return UIImage(named: "il_check_addr_ledger")
        } else if isQRMode {
            return JadeAsset.img(.selectDual, nil)
        } else {
            let isV2 = BleHwManager.shared.jade?.version?.boardType == .v2
            return JadeAsset.img(.select, isV2 ? .v2 : .v1)
        }
    }
    var isSwap: Bool {
        guard let draft else { return false }
        return (draft.swapPayResponse != nil ||
                draft.lockupResponse != nil ||
                draft.swapPosition != nil)
    }
}
