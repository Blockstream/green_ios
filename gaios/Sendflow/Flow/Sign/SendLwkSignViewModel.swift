import Foundation
import core
import gdk
import greenaddress
import UIKit
import BreezSDK
import LiquidWalletKit

class SendLwkSignViewModel {
    // Input
    let draft: TransactionDraft
    let denominationType: DenominationType
    let isFiat: Bool
    let subaccount: WalletItem
    let delegate: SendLwkSignViewModelDelegate?
    let tx: gdk.Transaction
    // Variables
    var sendTransactionSuccess: SendTransactionSuccess?
    var error: Error?
    // Property
    var addressee: Addressee? { tx.addressees.first }
    var address: String? { addressee?.address }
    var sendAll: Bool { addressee?.isGreedy ?? false}
    var satoshiWithFee: UInt64? {
        let feeAsset = subaccount.gdkNetwork.getFeeAsset()
        if let amount = tx.amountsWithFee[feeAsset] {
            return UInt64(abs(amount))
        }
        return nil
    }
    var swapId: String? {
        if let lockupResponse = draft.lockupResponse {
            return try? lockupResponse.swapId()
        } else if let swapPayResponse = draft.swapPayResponse {
            return try? swapPayResponse.swapId()
        } else {
            return nil
        }
    }
    var recipientSatoshi: UInt64? {
        if draft.swapPayResponse != nil {
            // try? draft.swapPayResponse?.uriAmount().satoshi
            return draft.satoshi
        } else if let swap = draft.swapPosition {
            return swap.to.amount
        } else {
            return txSatoshi
        }
    }
    var txFee: UInt64? { tx.fee }
    var totalFee: UInt64? { (providerFee ?? 0) + (claimNetworkFee ?? 0) + (tx.fee ?? 0) }
    var txSatoshi: UInt64? {
        let feeAsset = NetworkSecurityCase.liquidSS.gdkNetwork.getFeeAsset()
        if let amount = tx.amounts[feeAsset] {
            return UInt64(abs(amount))
        }
        return nil
    }

    var providerFee: UInt64? {
        if draft.lockupResponse != nil {
            return try? draft.lockupResponse?.boltzFee()
        } else if let swapPay = draft.swapPayResponse {
            return try? swapPay.boltzFee()
        }
        return nil
    }

    var claimNetworkFee: UInt64? {
        if draft.lockupResponse != nil {
            return draft.swapPosition?.networkFee ?? 0
        } else if let swapPay = draft.swapPayResponse {
            let swapFee = try? swapPay.fee()
            let boltzFee = try? swapPay.boltzFee()
            return (swapFee ?? 0) - (boltzFee ?? 0)
        }
        return nil
    }

    var networkFee: UInt64? {
        return (claimNetworkFee ?? 0) + (tx.fee ?? 0)
    }
    /*var totalAmount: Balance? {
        let feeAsset = subaccount.session?.gdkNetwork.getFeeAsset() ?? "btc"
        var amount = abs(tx.amounts[feeAsset] ?? 0)
        if feeAsset == assetIdFrom {
            amount += Int64(tx.fee ?? 0)
        }
        return Balance.fromSatoshi(amount, assetId: assetIdFrom)
    }*/
    var bolt11: Bolt11Invoice {
        get throws {
            switch draft.paymentTarget {
            case .lightningInvoice(let bolt11):
                return bolt11
            default:
                throw TransactionError.invalid(localizedDescription: "Invalid invoice")
            }
        }
    }
    var isCrossChainSwap: Bool {
        draft.lockupResponse != nil
    }
    var isSubmarineSwap: Bool {
        draft.swapPayResponse != nil
    }
    var subaccountFrom: WalletItem {
        if let swap = draft.swapPosition {
            return swap.from.account ?? subaccount
        }
        return draft.subaccount ?? subaccount
    }
    var subaccountTo: WalletItem? {
        if let swap = draft.swapPosition {
            return swap.to.account
        }
        return nil
    }
    var assetIdFrom: String {
        if let swap = draft.swapPosition {
            return swap.from.assetId
        }
        return draft.assetId ?? draft.network?.gdkNetwork.getFeeAsset() ?? "btc"
    }
    var assetIdTo: String? {
        if let swap = draft.swapPosition {
            return swap.to.assetId
        }
        return nil
    }
    var assetFrom: AssetInfo? { WalletManager.current?.info(for: assetIdFrom) }
    var assetTo: AssetInfo? { WalletManager.current?.info(for: assetIdTo) }
    var assetImageFrom: UIImage? { WalletManager.current?.image(for: assetIdFrom) }
    var assetImageTo: UIImage? { WalletManager.current?.image(for: assetIdTo) }
    // Functions
    init(
        transactionDraft: TransactionDraft,
        denominationType: DenominationType,
        isFiat: Bool = false,
        subaccount: WalletItem,
        delegate: SendLwkSignViewModelDelegate?,
        tx: gdk.Transaction
    ) {
        self.draft = transactionDraft
        self.denominationType = denominationType
        self.isFiat = isFiat
        self.subaccount = subaccount
        self.delegate = delegate
        self.tx = tx
    }

    func send() async {
        await delegate?.didSendLwkSignViewModelWillSend(self, transaction: tx)
    }
    func convertToDenom(satoshi: UInt64) -> String? {
        return Balance.fromSatoshi(satoshi, assetId: assetIdFrom)?.toText(denominationType)
    }
    func convertToFiat(satoshi: UInt64) -> String? {
        return Balance.fromSatoshi(satoshi, assetId: assetIdFrom)?.toFiatText()
    }
    func convertToText(satoshi: UInt64) -> String? {
        return isFiat ? convertToFiat(satoshi: satoshi) : convertToDenom(satoshi: satoshi)
    }
}
