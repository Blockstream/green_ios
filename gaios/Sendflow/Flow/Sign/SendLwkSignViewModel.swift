import Foundation
import core

import greenaddress
import UIKit
import LiquidWalletKit

class SendLwkSignViewModel {
    // Input
    let mainWallet: Wallet
    let draft: TransactionDraft
    let denominationType: DenominationType
    let isFiat: Bool
    let subaccount: Account
    let delegate: SendLwkSignViewModelDelegate?
    var tx: core.Transaction
    // Variables
    var sendTransactionSuccess: SendTransactionSuccess?
    var error: Error?
    // Property
    var addressee: Addressee? { tx.addressees.first }
    var address: String? { addressee?.address }
    var sendAll: Bool { addressee?.isGreedy ?? false}
    // Normalized recipient for the review screen. For LNURL/BOLT12 the gdk
    // transaction address points at the Liquid swap URI, not the user-facing
    // destination, so prefer the parsed payment target payload when available.
    var recipientAddress: String? {
        // BIP-353 is resolved into another target (BOLT12, BOLT11, BIP-21, …)
        // before routing reaches the review screen, so prefer the preserved
        // human-readable origin when available.
        if let origin = draft.bip353Origin {
            return origin
        }
        switch draft.paymentTarget {
        case .lightningInvoice(let bolt11):
            return bolt11.description
        case .lnUrl(let input, _):
            return input
        case .lightningOffer(let offer, _):
            return offer
        case .bip353(let input, _):
            return input
        default:
            return address
        }
    }
    // Submarine-swap subtitle phrased per payment target so users get the
    // correct destination kind on the review screen (invoice / LNURL / offer).
    var submarineSubtitle: String? {
        switch draft.paymentTarget {
        case .lightningInvoice:
            return "You are paying this Lightning invoice with Liquid bitcoin"
        case .lnUrl:
            return "You are paying this LNURL with Liquid bitcoin"
        case .lightningOffer:
            return "You are paying this Lightning offer with Liquid bitcoin"
        default:
            return nil
        }
    }
    // True when paying a lightning destination via the Lightning rail (the
    // selected subaccount is Lightning). False for Liquid -> Lightning swaps.
    var usesLightningRail: Bool { subaccount.networkId == .lightningMainnet }
    var note: String? {
        let description = try? bolt11.invoiceDescription()
        return tx.memo ?? description
    }
    var isNoteEditable : Bool {
        !usesLightningRail
    }
    var isNoteHidden : Bool {
        note?.isEmpty ?? true
    }
    var satoshiWithFee: UInt64? {
        if usesLightningRail {
            // LNURL on Lightning rail keeps `.lnUrl` as the draft payment target,
            // so the bolt11 accessor throws; fall back to the entered amount.
            return invoiceSatoshi
        }
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
        } else if let invoiceResponse = draft.invoiceResponse {
            return try? invoiceResponse.swapId()
        } else {
            return nil
        }
    }

    var recipientSatoshi: UInt64? {
        if draft.swapPayResponse != nil {
            let baseAmount = draft.satoshi ?? draft.swapPosition?.to.amount ?? 0
            let setupFee = draft.lightningSetupFee ?? 0
            return baseAmount > setupFee ? (baseAmount - setupFee) : 0
        } else if let swap = draft.swapPosition {
            return swap.to.amount
        } else {
            switch draft.paymentTarget {
            case .lightningInvoice(let bolt11Invoice):
                return bolt11Invoice
                    .amountMilliSatoshis()?.satoshi ?? draft.satoshi
            case .lightningOffer(_, let lightningPayment):
                return (try? lightningPayment.bolt12InvoiceAmount()) ?? draft.satoshi
            case .lnUrl(_, _):
                return draft.satoshi
            default:
                return txSatoshi
            }
        }
    }

    
    var txFee: UInt64? { tx.fee }
    var totalFee: UInt64? { (swapFee ?? 0) + (claimNetworkFee ?? 0) + (tx.fee ?? 0) + (lightningSetupFee ?? 0)  }
    var txSatoshi: UInt64? {
        let feeAsset = NetworkId.electrumLiquid.gdkNetwork.getFeeAsset()
        if let amount = tx.amounts[feeAsset] {
            return UInt64(abs(amount))
        }
        return nil
    }

    var swapFee: UInt64? {
        if draft.lockupResponse != nil {
            return try? draft.lockupResponse?.boltzFee()
        } else if let swapPay = draft.swapPayResponse {
            return try? swapPay.boltzFee()
        } else if draft.invoiceResponse != nil {
            return draft.swapPosition?.boltzFee
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
        } else if draft.invoiceResponse != nil {
            return draft.swapPosition?.networkFee ?? 0
        }
        return nil
    }

    var networkFee: UInt64? {
        return (claimNetworkFee ?? 0) + (tx.fee ?? 0)
    }
    
    var lightningSetupFee: UInt64? {
        return draft.lightningSetupFee
    }
    /*var totalAmount: Balance? {
        let feeAsset = subaccount.gdkSession?.gdkNetwork.getFeeAsset() ?? "btc"
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
    var invoiceSatoshi: UInt64? {
        draft.satoshi ?? (try? bolt11.amountMilliSatoshis()?.satoshi)
    }
    var isCrossChainSwap: Bool {
        draft.lockupResponse != nil
    }
    var isSubmarineSwap: Bool {
        draft.swapPayResponse != nil
    }
    var isInternalSwap: Bool {
        draft.swapPosition != nil
    }
    var isSwapTransaction: Bool {
        isCrossChainSwap || isSubmarineSwap || swapId != nil
    }
    var subaccountFrom: Account {
        if let swap = draft.swapPosition {
            return swap.from.account ?? subaccount
        }
        return draft.subaccount ?? subaccount
    }
    var subaccountTo: Account? {
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
        mainWallet: Wallet,
        transactionDraft: TransactionDraft,
        denominationType: DenominationType,
        isFiat: Bool = false,
        subaccount: Account,
        delegate: SendLwkSignViewModelDelegate?,
        tx: core.Transaction
    ) {
        self.mainWallet = mainWallet
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

    func hasMultipleSubaccounts(for account: Account) -> Bool {
        guard let wm = WalletManager.current else { return false }
        if account.networkId.liquid {
            return wm.liquidSubaccounts.count > 1
        } else if account.networkId.bitcoin {
            return wm.bitcoinSubaccounts.count > 1
        } else if account.networkId.lightning {
            return wm.lightningSubaccounts.count > 1
        }
        
        return false
    }
}
