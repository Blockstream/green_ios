import Foundation
import UIKit
import core
import gdk
import LiquidWalletKit
import greenaddress

@MainActor
final class SendAmountViewModel: Sendable {

    let wallet: WalletDataModel
    let mainAccount: Account
    var draft: TransactionDraft
    var denominationType: DenominationType
    var isFiat: Bool
    let subaccount: WalletItem
    let tx: gdk.Transaction?
    let delegate: SendAmountViewModelDelegate?

    // UI state
    var error: Error?
    var paymentTarget: PaymentTarget?

    // Callback for UI updates
    var onStateChanged: (() -> Void)?

    var isLightningPayment: Bool { subaccount.networkType == .lightning }
    var isRedepositExpired2FA: Bool { false }
    var canContinue: Bool {
        error == nil && satoshi != nil
    }
    var isSwapTarget: Bool {
        draft.paymentTarget?.isLightningSwapTarget ?? false
    }
    // Lightning rail caps the payment by node capacity; Liquid rail caps it
    // by subaccount balance, so the user-facing label differs.
    var availableLabel: String {
        if isLightningPayment {
            return "Max single payment amount".localized
        }
        return "id_available".localized
    }
    var screenTitle: String {
        if isRedepositExpired2FA {
            return "id_reenable_2fa".localized
        }
        switch draft.paymentTarget {
        case .lnUrl:
            return "LNURL amount"
        case .lightningOffer:
            return "BOLT12 amount"
        default:
            return "id_send".localized
        }
    }

    init(
        mainAccount: Account,
        wallet: WalletDataModel,
        draft: TransactionDraft,
        tx: gdk.Transaction?,
        subaccount: WalletItem,
        denominationType: DenominationType,
        isFiat: Bool,
        delegate: SendAmountViewModelDelegate
    ) {
        self.mainAccount = mainAccount
        self.wallet = wallet
        self.draft = draft
        self.tx = tx
        self.subaccount = subaccount
        self.delegate = delegate
        self.denominationType = denominationType
        self.isFiat = isFiat
    }

    var assetId: String { draft.assetId ?? draft.network?.gdkNetwork.getFeeAsset() ?? "btc" }
    var asset: AssetInfo? { WalletManager.current?.info(for: assetId) }
    var assetImage: UIImage? { WalletManager.current?.image(for: assetId) }

    var hasPrice: Bool {
        let fiat = Balance.fromSatoshi(Int64(0), assetId: assetId)?.toFiat().0
        if (fiat ?? "").isEmpty {
            return false
        }
        return true
    }

    var amountText: String? {
        didSet {
            if let amountText, !amountText.isEmpty {
                if isFiat {
                    satoshi = Balance
                        .fromFiat(amountText, assetId: assetId)?.satoshi
                        .map { UInt64($0)}
                } else {
                    satoshi = Balance
                        .from(
                            amountText,
                            assetId: assetId,
                            denomination: denominationType
                        )?.satoshi
                        .map { UInt64($0)}

                }
            } else {
                satoshi = nil
            }
        }
    }

    var satoshi: UInt64? {
        didSet {
            draft.satoshi = satoshi
        }
    }

    func triggerValidation() {
        Task {
            do {
                try await validate()
                self.error = nil
            } catch {
                self.error = error
            }
            onStateChanged?()
        }
    }

    func validate() async throws {
        guard let satoshi else { return }
        if satoshi > maxSendAmount ?? 0 {
            throw SendFlowError.insufficientFunds
        }
    }
/*
    func loadFees() async {
        await feeEstimator?.refreshFeeEstimates()
    }
    var feeRate: UInt64? {
        if transactionPriority == .Custom {
            return createTx.feeRate
        } else {
            return feeEstimator?.feeRate(at: transactionPriority)
        }
    }
    var feeRateText: String? { feeRateWithUnit(feeRate ?? 0) }
    func feeRateWithUnit(_ value: UInt64) -> String {
        let feePerByte = Double(value) / 1000.0
        return String(format: "%.2f sats / vbyte", feePerByte)
    }

    var feeTimeText: String? {
        if transactionPriority == .Custom {
            return ""
        } else {
            return transactionPriority.time(isLiquid: createTx.isLiquid)
        }
    }

    var fee: Balance? {
        let feeAsset = session?.gdkNetwork.getFeeAsset()
        if let fee = transaction?.fee {
            return Balance.fromSatoshi(fee, assetId: feeAsset ?? "btc")
        }
        return nil
    }

    var totalWithoutFee: Balance? {
        let feeAsset = session?.gdkNetwork.getFeeAsset()
        let assetId = createTx.assetId ?? feeAsset ?? "btc"
        var amount = transaction?.amounts[assetId]
        if createTx.txType == .redepositExpiredUtxos {
            amount = createTx.addressee.satoshi ?? 0
        }
        guard let amount = amount else { return nil }
        return Balance.fromSatoshi(abs(amount), assetId: assetId)
    }

    var total: Balance? {
        let feeAsset = session?.gdkNetwork.getFeeAsset()
        var satoshi = totalWithoutFee?.satoshi ?? 0
        if createTx.txType == .redepositExpiredUtxos {
            satoshi = createTx.addressee.satoshi ?? 0
        }
        if feeAsset == assetId {
            satoshi += Int64(transaction?.fee ?? 0)
        }
        return Balance.fromSatoshi(satoshi, assetId: assetId)
    }

    var walletBalanceDenomText: String? { walletBalance?.toText(denominationType) }
    var walletBalanceFiatText: String? { walletBalance?.toFiatText() }
    var amountDenomText: String? { amount?.toValue(denominationType, locale: false).0 }
    var amountFiatText: String? { amount?.toFiat(locale: false).0 }
    var subamountDenomText: String? { subamount?.toValue(denominationType).0 }
    var subamountFiatText: String? { subamount?.toFiat().0 }
    var amountSendAllDenomText: String? { amountSendAll?.toValue(denominationType).0 }
    var amountSendAllFiatText: String? { amountSendAll?.toFiatText() }
    var totalDenomText: String? { total?.toText(denominationType) }
    var totalFiatText: String? { total?.toFiatText() }
    var feeDenomText: String? { fee?.toText(denominationType) }
    var feeFiatText: String? { fee?.toFiatText() == nil ? nil : "≈ \(fee?.toFiatText() ?? "")" }
    var totalWithoutFeeDenom: String? { totalWithoutFee?.toValue(denominationType).0 }
    var totalWithoutFeeFiat: String? { totalWithoutFee?.toFiat().0 }
    var totalWithoutFeeDenomText: String? { totalWithoutFee?.toText(denominationType) }
    var totalWithoutFeeFiatText: String? { totalWithoutFee?.toFiatText() }

    var walletBalanceText: String? { isFiat ? walletBalanceFiatText : walletBalanceDenomText }

    var amountText: String? {
        if createTx.txType == .sweep || (sendAll && createTx.txType != .redepositExpiredUtxos) {
            return isFiat ? totalWithoutFeeFiat : totalWithoutFeeDenom
        } else {
            return isFiat ? amountFiatText : amountDenomText
        }
    }
    var subamountText: String? {
        if createTx.txType == .sweep || (sendAll && createTx.txType != .redepositExpiredUtxos) {
            return isFiat ? "\(totalWithoutFeeDenom ?? "") \(denomination ?? "")" : "≈ \(totalWithoutFeeFiat ?? "") \(fiatCurrency ?? "")"
        } else {
            return isFiat ? "\(subamountDenomText ?? "") \(denomination ?? "")" : "≈ \(subamountFiatText ?? "") \(fiatCurrency ?? "")"
        }
    }
    var conversionText: String? {
        return isFiat ? "\(totalDenomText ?? "")" : "\(totalFiatText ?? "")"
    }
    var totalText: String? { isFiat ? totalFiatText : totalDenomText }
    var feeText: String? { isFiat ? feeFiatText : feeDenomText }
    var feeConvertText: String? { !isFiat ? feeFiatText : feeDenomText }
    var totalWithoutFeeText: String? { isFiat ? totalWithoutFeeFiatText : totalWithoutFeeDenomText }
*/
    var amountEditable: Bool {
        switch draft.paymentTarget {
        case .lightningInvoice(let invoice):
            return invoice.amountMilliSatoshis() == nil
        case .lightningOffer:
            return true
        case .lnUrl:
            return true
        case .privateKey:
            return false
        default:
            return !(draft.sendAll ?? false) && !isRedepositExpired2FA
        }
    }

    var sendAllEnabled: Bool {
        switch draft.paymentTarget {
        case .lightningInvoice(let invoice):
            return invoice.amountMilliSatoshis() == nil
        case .lightningOffer:
            return false
        case .lnUrl:
            return false
        case .privateKey:
            return false
        default:
            return !(draft.sendAll ?? false) && !isRedepositExpired2FA
        }
    }

    var sendAll: Bool = false {
        didSet {
            draft.sendAll = sendAll
        }
    }
    var maxSendAmount: UInt64? {
        if subaccount.isLightning {
            return subaccount.lightningSession?
                .nodeState()?.maxPayableMsat.satoshi
        } else {
            return UInt64(subaccount.btc ?? 0)
        }
    }
    var currency: String {
        Balance.fromSatoshi(Int64(0), assetId: assetId)?.toFiat().1 ?? ""
    }
    var ticker: String {
        Balance
            .fromSatoshi(Int64(0), assetId: assetId)?
            .toValue(denominationType).1 ?? ""
    }
    var currencyOrTicker: String {
        return isFiat ? currency : ticker
    }
    func convertToDenom(_ satoshi: UInt64) -> String? {
        return Balance.fromSatoshi(satoshi, assetId: assetId)?.toText(denominationType)
    }
    func convertToFiat(_ satoshi: UInt64) -> String? {
        return Balance.fromSatoshi(satoshi, assetId: assetId)?.toFiatText()
    }
    func convertToText(_ satoshi: UInt64) -> String? {
        return isFiat ? convertToFiat(satoshi) : convertToDenom(satoshi)
    }

    func dialogInputDenominationViewModel() -> DialogInputDenominationViewModel? {
        let list: [DenominationType] = [ .BTC, .MilliBTC, .MicroBTC, .Bits, .Sats]
        let balance = Balance.fromSatoshi(
            satoshi ?? 0,
            assetId: assetId)
        return DialogInputDenominationViewModel(
            denomination: denominationType,
            denominations: list,
            network: subaccount.networkType,
            isFiat: isFiat,
            balance: balance)
    }

    func dialogLiquidAssetToFiatViewModel() -> DialogLiquidAssetToFiatViewModel {
        if let satoshi {
            return DialogLiquidAssetToFiatViewModel(
                assetName: asset?.ticker ?? "",
                assetAmountTxt: convertToDenom(satoshi) ?? "",
                fiatAmountTxt: convertToFiat(satoshi) ?? "",
                isFiat: isFiat)
        }
        return DialogLiquidAssetToFiatViewModel(
            assetName: asset?.ticker ?? "",
            assetAmountTxt: "",
            fiatAmountTxt: "",
            isFiat: isFiat)
    }

    func next() {
        delegate?.sendAmountViewModel(self, draft: draft)
    }
}
