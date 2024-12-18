import UIKit
import gdk
import core

enum TxDetailsAction {
    case speedUp
    case addNote
    case explorer
    case shareTx
    case more
    case refund
}

class TxDetailsViewModel {

    var wallet: WalletItem
    var transaction: Transaction
    var assetAmountList: AssetAmountList

    var cells = ["TxDetailsStatusCell", "TxDetailsAmountCell", "TxDetailsMultiAmountCell",
                 "TxDetailsActionCell", "TxDetailsInfoCell", "TxDetailsTotalsCell"]

    private var hideBalance: Bool {
        return UserDefaults.standard.bool(forKey: AppStorageConstants.hideBalance.rawValue)
    }

    init(wallet: WalletItem, transaction: Transaction) {
        self.wallet = wallet
        self.transaction = transaction
        self.assetAmountList = AssetAmountList(transaction.amountsWithoutFees)
    }

    var txDetailsStatusCellModel: TxDetailsStatusCellModel {
        let blockHeight: UInt32 = wallet.session?.blockHeight ?? 0
        return TxDetailsStatusCellModel(transaction: transaction,
                                        blockHeight: blockHeight,
                                        assetAmountList: assetAmountList)
    }

    var txDetailsAmountCellModels: [TxDetailsAmountCellModel] {
        return assetAmountList.amounts.map {
            var amount = $0.1
            let assetId = transaction.subaccountItem?.gdkNetwork.getFeeAsset() ?? "btc"
            if ($0.0 == assetId) && transaction.type == .outgoing {
                amount = -(abs($0.1) - Int64(transaction.fee ?? 0))
            }
            return TxDetailsAmountCellModel(tx: transaction,
                                     isLightning: wallet.type.lightning,
                                     id: $0.0,
                                     value: amount,
                                     hideBalance: hideBalance)
        }
    }

    var showTotals: Bool {
        if !transaction.isLightning && transaction.type == .outgoing && assetAmountList.amounts.count == 1 {
            let amount: (String, Int64) = assetAmountList.amounts[0]
            let assetId = transaction.subaccountItem?.gdkNetwork.getFeeAsset() ?? "btc"
            if amount.0 == assetId {
                return true
            }
        }
        return false
    }

    var txDetailsTotalsCellModels: [TxDetailsTotalsCellModel] {
        var items = [TxDetailsTotalsCellModel]()
        if !showTotals { return items }

        var totalSpent: String?
        var conversion: String?
        var ntwFees: String?
        var receive: String?

        let amount: (String, Int64) = assetAmountList.amounts[0]
        let assetId = transaction.subaccountItem?.gdkNetwork.getFeeAsset() ?? "btc"
        if amount.0 == assetId {
            let tSpent = abs(amount.1)
            if let balance = Balance.fromSatoshi(tSpent, assetId: assetId) {
                let (amount, denom) = balance.toValue()
                let (fiat, fiatCurrency) = balance.toFiat()
                totalSpent = "\(amount) \(denom)"
                conversion = "≈ \(fiat) \(fiatCurrency)"
            }
            if let balance = Balance.fromSatoshi(transaction.fee ?? 0, assetId: assetId) {
                let (amount, denom) = balance.toValue()
                ntwFees = "\(amount) \(denom)"
            }
            let spent = abs(amount.1) - Int64(transaction.fee ?? 0)
            if let balance = Balance.fromSatoshi(spent, assetId: assetId) {
                let (amount, denom) = balance.toValue()
                receive = "\(amount) \(denom)"
            }
        }

        if let totalSpent = totalSpent, let conversion = conversion, let ntwFees = ntwFees, let receive = receive {
            items.append(TxDetailsTotalsCellModel(totalSpent: totalSpent,
                                                  conversion: conversion,
                                                  ntwFees: ntwFees,
                                                  receive: receive,
                                                  hideBalance: hideBalance))
        }
        return items
    }

    var txDetailsInfoCellModels: [TxDetailsInfoCellModel] {

        var items = [TxDetailsInfoCellModel]()

        // address
        if let address = address(transaction) {

            var title = ""
            switch transaction.type {
            case .redeposit:
                title = "id_redeposited".localized
            case .incoming:
                title = "id_received_on".localized
            case .outgoing:
                title = "id_sent_to".localized
            case .mixed:
                title = "id_swapped".localized
            }

            let hint = address
            items.append(TxDetailsInfoCellModel(title: title,
                                                hint: hint,
                                                type: .address,
                                                hideBalance: hideBalance))
        }

        if transaction.type != .incoming &&
            !(transaction.isRefundableSwap ?? false) &&
            !showTotals {

            // fee
            if let balance = Balance.fromSatoshi(transaction.fee ?? 0, assetId: transaction.subaccountItem?.gdkNetwork.getFeeAsset() ?? "btc") {
                let (amount, denom) = balance.toValue()
                let (fiat, fiatCurrency) = balance.toFiat()
                let str = "\(amount) \(denom) ≈ \(fiat) \(fiatCurrency)"

                items.append(TxDetailsInfoCellModel(title: "id_network_fees".localized, hint: str, type: .fee, hideBalance: hideBalance))
            }

            // fee rate
//            if transaction.isLightning {} else {
//                items.append(TxDetailsInfoCellModel(title: "id_fee_rate".localized, hint: "\(String(format: "%.2f satoshi / vbyte", Double(transaction.feeRate) / 1000))", type: .feeRate, hideBalance: hideBalance))
//            }
        }

        // transaction Id
        if !transaction.isLightning {
//            items.append(TxDetailsInfoCellModel(title: "id_transaction_id".localized,
//                                                hint: transaction.hash ?? "",
//                                                type: .txId,
//                                                hideBalance: hideBalance))
        }

        // note
        if !(transaction.memo ?? "").isEmpty {
            items.append(TxDetailsInfoCellModel(title: "id_note".localized,
                                                hint: transaction.memo ?? "",
                                                type: .memo,
                                                hideBalance: hideBalance))
        }

        // message
        if transaction.isLightning && transaction.message != nil {
            items.append(TxDetailsInfoCellModel(title: "id_message".localized,
                                                hint: transaction.message ?? "",
                                                type: .message,
                                                hideBalance: hideBalance))
        }
        // url
        if transaction.isLightning && transaction.url != nil {
            let url = transaction.url ?? ("", "")
            items.append(TxDetailsInfoCellModel(title: url.0,
                                                hint: url.1,
                                                type: .url,
                                                hideBalance: hideBalance))
        }
        // plaintext
        if transaction.isLightning && transaction.plaintext != nil {
            let plaintext = transaction.plaintext ?? ("", "")
            items.append(TxDetailsInfoCellModel(title: plaintext.0,
                                                hint: plaintext.1,
                                                type: .plaintext,
                                                hideBalance: hideBalance))
        }

        return items
    }

    var txDetailsActionCellModels: [TxDetailsActionCellModel] {

        var models: [TxDetailsActionCellModel] = []

        if showBumpFee() {
            models.append(
                TxDetailsActionCellModel(icon: UIImage(named: "ic_tx_action_speed")!,
                                         title: "id_speed_up_transaction".localized,
                                         action: .speedUp)
            )
        }
        if transaction.isLightning {} else {
            models.append(
                TxDetailsActionCellModel(icon: UIImage(named: "ic_tx_action_note")!,
                                         title: Common.noteActionName(transaction.memo ?? ""),
                                         action: .addNote)
            )
        }
        if (transaction.isLightning) {} else {
            models.append(
                TxDetailsActionCellModel(icon: UIImage(named: "ic_tx_action_explorer")!.maskWithColor(color: UIColor.gGreenMatrix()),
                                         title: "id_view_in_explorer".localized,
                                         action: .explorer)
            )
        }
        if transaction.isLightning {} else {
            models.append(
                TxDetailsActionCellModel(icon: UIImage(named: "ic_tx_action_share")!,
                                         title: "id_share_transaction".localized,
                                         action: .shareTx)
            )
        }

        if transaction.isLightning && !(transaction.isRefundableSwap ?? false) {
            models.append(
                TxDetailsActionCellModel(icon: UIImage(named: "ic_tx_action_more")!,
                                         title: "id_more_details".localized,
                                         action: .more)
            )
        }

        if transaction.isLightning && transaction.isRefundableSwap ?? false {
            models.append(
                TxDetailsActionCellModel(icon: UIImage(named: "ic_tx_action_revert")!.maskWithColor(color: UIColor.gGreenMatrix()),
                                         title: "id_initiate_refund".localized,
                                         action: .refund)
            )
        }

        return models
    }

    func showBumpFee() -> Bool {
        let subaccount =  WalletManager.current?.subaccounts.filter { $0.hashValue == transaction.subaccount }.first
        let isWatchonly = WalletManager.current?.account.isWatchonly ?? false
        let showBumpFee = !transaction.isLiquid && transaction.canRBF && !(subaccount?.session?.isResetActive ?? false)
        return showBumpFee
    }

    func address(_ tx: Transaction) -> String? {
        if tx.isLiquid {
            return nil
        }
        if tx.isLightning {
            if tx.isRefundableSwap ?? false || tx.isInProgressSwap ?? false {
                return tx.inputs?.first?.address
            } else {
                return nil
            }
        }
        switch tx.type {
        case .outgoing:
            let output = tx.outputs?.filter { $0.isRelevant ?? false == false}.first
            return output?.address
        case .incoming:
            let output = tx.outputs?.filter { $0.isRelevant ?? true == true}.first
            return output?.address
        default:
            return nil
        }
    }

}
