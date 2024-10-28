import Foundation
import core
import gdk
import greenaddress
import UIKit

enum Redeposit2faType {
    case single
    case multi
}

class SendAmountViewModel {

    var createTx: CreateTx
    var subaccount: WalletItem? { createTx.subaccount }
    var assetId: String { createTx.assetId ?? subaccount?.gdkNetwork.getFeeAsset() ?? "btc" }
    var wm: WalletManager? { WalletManager.current }
    var session: SessionManager? { createTx.subaccount?.session }
    var denominationType: DenominationType = .BTC
    var transaction: Transaction?
    var transactionPriority: TransactionPriority = .Medium
    var isFiat = false
    var hasHW: Bool { wm?.account.isHW ?? false }

    var feeEstimator: FeeEstimator?
    var validateTask: Task<Transaction?, Error>?

    var redeposit2faType: Redeposit2faType? {
        if createTx.txType != .redepositExpiredUtxos {
            return nil
        }
        if let addressees = transaction?.addressees {
            return addressees.count > 1 ? .multi : .single
        }
        return nil
    }

    var error: String? {
        if let error = transaction?.error, !error.isEmpty {
            return error
        }
        return nil
    }

    var sendAll: Bool {
        get { createTx.sendAll }
        set { createTx.sendAll = newValue }
    }

    var amountEditable: Bool {
        if createTx.isLightning {
            return createTx.anyAmounts ?? false
        } else {
            return createTx.txType == .transaction && !createTx.sendAll
        }
    }

    var sendAllEnabled: Bool {
        if createTx.isLightning {
            return false
        } else {
            return createTx.txType == .transaction
        }
    }

    init(createTx: CreateTx, transaction: Transaction? = nil) {
        self.createTx = createTx
        self.transaction = transaction
        self.denominationType = wm?.prominentSession?.settings?.denomination ?? .BTC
        self.feeEstimator = FeeEstimator(session: session!)
        if transaction?.previousTransaction != nil {
            transactionPriority = .Custom
        }
    }

    var walletBalance: Balance? {
        if let satoshi = subaccount?.satoshi?[assetId] {
            return Balance.fromSatoshi(satoshi, assetId: assetId)
        }
        return nil
    }

    var amount: Balance? {
        guard let satoshi = createTx.satoshi else { return nil }
        return Balance.fromSatoshi(satoshi, assetId: assetId)
    }
    var subamount: Balance? {
        return Balance.fromSatoshi(createTx.satoshi ?? 0, assetId: assetId)
    }

    var amountSendAll: Balance? {
        let feeAsset = session?.gdkNetwork.getFeeAsset()
        let assetId = createTx.assetId ?? feeAsset ?? "btc"
        guard let amount = transaction?.amounts[assetId] else {
            return nil
        }
        var satoshi = abs(amount)
        // sum fee on amount for base asset
        if feeAsset == assetId && createTx.sendAll {
            satoshi -= Int64(transaction?.fee ?? 0)
        }
        return Balance.fromSatoshi(satoshi, assetId: assetId)
    }

    var denomination: String? {
        Balance.fromSatoshi(0, assetId: assetId)?.toValue(denominationType).1
    }

    var fiatCurrency: String? {
        Balance.fromSatoshi(0, assetId: assetId)?.toFiat().1
    }

    var assetImage: UIImage? {
        if createTx.isLightning {
            return UIImage(named: "ic_lightning_btc")
        }
        return wm?.image(for: assetId)
    }

    var assetInfo: AssetInfo? {
        var asset = wm?.info(for: assetId)
        if asset?.assetId == session?.gdkNetwork.getFeeAsset() {
            asset?.ticker = denomination
        }
       return asset
    }

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
            amount = createTx.addressee?.satoshi ?? 0
        }
        guard let amount = amount else { return nil }
        return Balance.fromSatoshi(abs(amount), assetId: assetId)
    }

    var total: Balance? {
        let feeAsset = session?.gdkNetwork.getFeeAsset()
        var satoshi = totalWithoutFee?.satoshi ?? 0
        if createTx.txType == .redepositExpiredUtxos {
            satoshi = createTx.addressee?.satoshi ?? 0
        }
        if feeAsset == assetId {
            satoshi += Int64(transaction?.fee ?? 0)
        }
        return Balance.fromSatoshi(satoshi, assetId: assetId)
    }

    var walletBalanceDenomText: String? { walletBalance?.toText(denominationType) }
    var walletBalanceFiatText: String? { walletBalance?.toFiatText() }
    var amountDenomText: String? { amount?.toValue(denominationType).0 }
    var amountFiatText: String? { amount?.toFiat().0 }
    var subamountDenomText: String? { subamount?.toValue(denominationType).0 }
    var subamountFiatText: String? { subamount?.toFiat().0 }
    var amountSendAllDenomText: String? { amountSendAll?.toValue(denominationType).0 }
    var amountSendAllFiatText: String? { amountSendAll?.toFiatText() }
    var totalDenomText: String? { total?.toText(denominationType) }
    var totalFiatText: String? { total?.toFiatText() }
    var feeDenomText: String? { fee?.toText(denominationType) }
    var feeFiatText: String? { fee?.toFiatText() }
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
            return isFiat ? "\(totalWithoutFeeDenom ?? "") \(denomination ?? "")" : "\(totalWithoutFeeFiat ?? "") \(fiatCurrency ?? "")"
        } else {
            return isFiat ? "\(subamountDenomText ?? "") \(denomination ?? "")" : "\(subamountFiatText ?? "") \(fiatCurrency ?? "")"
        }
    }
    var conversionText: String? {
        return isFiat ? "\(totalDenomText ?? "")" : "\(totalFiatText ?? "")"
    }
    var totalText: String? { isFiat ? totalFiatText : totalDenomText }
    var feeText: String? { isFiat ? feeFiatText : feeDenomText }
    var totalWithoutFeeText: String? { isFiat ? totalWithoutFeeFiatText : totalWithoutFeeDenomText }

    func dialogInputDenominationViewModel() -> DialogInputDenominationViewModel? {
        let list: [DenominationType] = [ .BTC, .MilliBTC, .MicroBTC, .Bits, .Sats]
        let selected = denominationType // session?.settings?.denomination ?? .BTC
        let network: NetworkSecurityCase = session?.gdkNetwork.mainnet ?? true ? .bitcoinSS : .testnetSS
        return DialogInputDenominationViewModel(
            denomination: selected,
            denominations: list,
            network: network,
            isFiat: isFiat,
            balance: sendAll || createTx.privateKey != nil ? totalWithoutFee : amount)
    }

    func sendDialogFeeViewModel() -> SendDialogFeeViewModel? {
        SendDialogFeeViewModel(
            transaction: transaction,
            feeEstimator: feeEstimator,
            denominationType: denominationType,
            subaccount: subaccount)
    }

    func sendSendTxConfirmViewModel() -> SendTxConfirmViewModel? {
        SendTxConfirmViewModel(
            transaction: transaction,
            subaccount: subaccount,
            denominationType: denominationType,
            isFiat: isFiat,
            txType: createTx.txType,
            unsignedPsbt: nil,
            signedPsbt: nil
        )
    }

    func validate() -> Task<Transaction?, Error>? {
        validateTask?.cancel()
        validateTask = Task {
            if let tx = try await validateTransaction() {
                self.transaction = tx
                return tx
            }
            return nil
        }
        return validateTask
    }

    private func validateTransaction() async throws -> Transaction? {
        var tx = Transaction(self.transaction?.details ?? [:])
        tx.subaccount = subaccount?.hashValue
        if Task.isCancelled { return nil }
        if let feeRate = createTx.feeRate {
            tx.feeRate = feeRate
        } else if let feeRate = feeRate {
            tx.feeRate = feeRate
        }
        switch createTx.txType {
        case .transaction, .psbt:
            if createTx.sendAll && createTx.satoshi == nil {
                createTx.satoshi = 0
            }
            if let addressee = createTx.addressee {
                tx.addressees = [addressee]
            }
        case .sweep:
            tx.sessionSubaccount = subaccount?.pointer ?? 0
            tx.privateKey = createTx.privateKey
            if tx.addressees.isEmpty {
                var address = try await session?.getReceiveAddress(subaccount: subaccount?.pointer ?? 0)
                address?.isGreedy = true
                address?.satoshi = 0
                var addressee = address.toDict()
                let btc = tx.subaccountItem?.gdkNetwork.getFeeAsset()
                addressee?["id_asset"] = btc
                tx.details["addressees"] = [addressee]
            }
            if tx.utxos?.isEmpty ?? true {
                do {
                    let unspent = try await session?.getUnspentOutputsForPrivateKey(UnspentOutputsForPrivateKeyParams(privateKey: tx.privateKey ?? "", password: nil))
                    tx.utxos = unspent ?? [:]
                } catch {
                    tx.error = error.description()
                    return tx
                }
            }
        case .bumpFee:
            tx.sessionSubaccount = subaccount?.pointer ?? 0
            tx.previousTransaction = createTx.previousTransaction
        case .bolt11:
            if let addressee = createTx.addressee {
                tx.addressees = [addressee]
            }
            tx.anyAmouts = createTx.anyAmounts ?? false
        case .lnurl:
            if let addressee = createTx.addressee {
                tx.addressees = [addressee]
            }
            tx.anyAmouts = createTx.anyAmounts ?? false
        case .redepositExpiredUtxos:
            let feeRate = createTx.feeRate ?? feeRate
            let guParams = GetUnspentOutputsParams(subaccount: subaccount?.pointer ?? 0, numConfs: 1)
            let res = try await session?.getUtxos(guParams)
            let crtParams = CreateRedepositTransactionParams(utxos: res?.unspentOutputs ?? [:], feeRate: feeRate, feeSubaccount: subaccount?.pointer ?? 0, expiredAt: nil, expiresIn: nil)
            var created = try await session?.createRedepositTransaction(params: crtParams)
            created?.subaccount = subaccount?.hashValue
            createTx.addressee = created?.addressees.first
            return created
        }
        if [TxType.transaction, TxType.bumpFee].contains(where: {$0 == createTx.txType }) && tx.utxos == nil {
            let unspent = try? await session?.getUnspentOutputs(GetUnspentOutputsParams(subaccount: subaccount?.pointer ?? 0, numConfs: 0))
            tx.utxos = unspent ?? [:]
        }
        self.transaction = tx
        if Task.isCancelled { return nil }
        tx.amounts = [:]
        var created = try? await session?.createTransaction(tx: tx)
        created?.subaccount = subaccount?.hashValue
        return created
    }

    func getExpiredUtxos() async throws -> [String: [[String: Any]]] {
        let params = GetUnspentOutputsParams(subaccount: subaccount?.pointer ?? 0, numConfs: 1, expiredAt: UInt64(session?.blockHeight ?? 0))
        return try await session?.getUnspentOutputs(params) ?? [:]
    }

    func getAssetIcons() -> [UIImage] {
        transaction?.addressees.compactMap { $0.assetId }.compactMap { self.wm?.image(for: $0) } ?? []
    }

    var showFeesInTotals: Bool {
        if createTx.isLiquid {
            return feeEstimator?.feeRate(at: .High) ?? 0 > session?.gdkNetwork.defaultFee ?? 0
        }
        return true
    }
}
