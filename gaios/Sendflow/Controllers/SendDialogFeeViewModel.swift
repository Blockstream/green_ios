import Foundation
import core

import greenaddress
import UIKit

class SendDialogFeeViewModel {

    var transaction: Transaction
    var feeEstimator: FeeEstimator?
    var denominationType: DenominationType?
    var subaccount: Account?

    var fastFeeTx: Transaction?
    var mediumFeeTx: Transaction?
    var lowFeeTx: Transaction?
    var customFeeTx: Transaction?

    var fastFeeRate: UInt64? { feeEstimator?.feeRate(at: .High) }
    var mediumFeeRate: UInt64? { feeEstimator?.feeRate(at: .Medium) }
    var lowFeeRate: UInt64? { feeEstimator?.feeRate(at: .Low) }

    var isLiquid: Bool { transaction.isLiquid }

    init(transaction: Transaction?, feeEstimator: FeeEstimator?, denominationType: DenominationType?, subaccount: Account?) {
        self.transaction = transaction ?? Transaction([:])
        self.feeEstimator = feeEstimator
        self.denominationType = denominationType
        self.subaccount = subaccount
    }

    func loadTx(feeRate: UInt64) async throws -> Transaction? {
        var tx = transaction
        tx.feeRate = feeRate
        return try await subaccount?.gdkSession?.createTransaction(tx: tx)
    }

    func loadTxs() async {
        lowFeeTx = try? await loadTx(feeRate: lowFeeRate ?? 0)
        mediumFeeTx = try? await loadTx(feeRate: mediumFeeRate ?? 0)
        fastFeeTx = try? await loadTx(feeRate: fastFeeRate ?? 0)
    }

    func btcToText(_ satoshi: UInt64?) -> String? {
        guard let satoshi = satoshi else { return nil }
        return Balance
            .fromSatoshi(
                satoshi,
                assetId: transaction.networkIdInjected?.gdkNetwork
                    .getFeeAsset() ?? "btc"
            )?
            .toText(denominationType)
    }
    func btcToFiat(_ satoshi: UInt64?) -> String? {
        guard let satoshi = satoshi else { return nil }
        return Balance
            .fromSatoshi(
                satoshi,
                assetId: transaction.networkIdInjected?.gdkNetwork
                    .getFeeAsset() ?? "btc"
            )?
            .toFiatText()
    }

    func feeRateWithUnit(_ value: UInt64?) -> String? {
        guard let value = value else { return nil }
        let feePerByte = Double(value) / 1000.0
        return String(format: "%.2f sats / vB", feePerByte)
    }

    private func formatFiat(_ satoshi: UInt64?) -> String {
        guard let fiat = btcToFiat(satoshi), !fiat.isEmpty else { return "" }
        return "≈ \(fiat)"
    }

    var fastSendFeeCellModel: SendFeeCellModel {
        SendFeeCellModel(speedName: "id_fast".localized,
                         time: "≈ \(TransactionPriority.High.shortTime(isLiquid: subaccount?.networkId.liquid ?? false))",
                         amount: btcToText(fastFeeTx?.fee) ?? "",
                         rate: feeRateWithUnit(fastFeeRate) ?? "",
                         fiat: formatFiat(fastFeeTx?.fee),
                         error: severe(fastFeeTx?.error) ? fastFeeTx?.error?.localized : nil,
                         feeRate: fastFeeRate,
                         transactionPriority: TransactionPriority.High)
    }
    var mediumSendFeeCellModel: SendFeeCellModel {
        SendFeeCellModel(speedName: "id_medium".localized,
                         time: "≈ \(TransactionPriority.Medium.shortTime(isLiquid: subaccount?.networkId.liquid ?? false))",
                         amount: btcToText(mediumFeeTx?.fee) ?? "",
                         rate: feeRateWithUnit(mediumFeeRate) ?? "",
                         fiat: formatFiat(mediumFeeTx?.fee),
                         error: severe(mediumFeeTx?.error) ? mediumFeeTx?.error?.localized : nil,
                         feeRate: mediumFeeRate,
                         transactionPriority: TransactionPriority.Medium)
    }
    var lowSendFeeCellModel: SendFeeCellModel {
        SendFeeCellModel(speedName: "id_slow".localized,
                         time: "≈ \(TransactionPriority.Low.shortTime(isLiquid: subaccount?.networkId.liquid ?? false))",
                         amount: btcToText(lowFeeTx?.fee) ?? "",
                         rate: feeRateWithUnit(lowFeeRate) ?? "",
                         fiat: formatFiat(lowFeeTx?.fee),
                         error: severe(lowFeeTx?.error) ? lowFeeTx?.error?.localized : nil,
                         feeRate: lowFeeRate,
                         transactionPriority: TransactionPriority.Low)
    }

    var cellModels: [SendFeeCellModel] {
        return [
            fastSendFeeCellModel,
            mediumSendFeeCellModel,
            lowSendFeeCellModel
        ]
    }

    func severe(_ error: String?) -> Bool {
        ["id_insufficient_funds",
         "id_fee_rate_is_above_maximum",
         "id_fee_rate_is_below_minimum",
         "Insufficient funds for fees"
        ].contains(error)
    }
}
