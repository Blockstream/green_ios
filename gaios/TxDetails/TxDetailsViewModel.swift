import UIKit
import gdk
import core

enum TxDetailsAction {
    case speedUp
    case addNote
    case explorer
    case shareTx
    case more
}

class TxDetailsViewModel {

    var wallet: WalletItem
    var transaction: Transaction
    var assetAmountList: AssetAmountList
    var swapId: String?
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
            let assetId = transaction.subaccount?.gdkNetwork.getFeeAsset() ?? "btc"
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
        return !transaction.isLightning && transaction.type == .outgoing /* && assetAmountList.amounts.count == 1 */
    }

    var txDetailsTotalsCellModels: [TxDetailsTotalsCellModel] {
        var items = [TxDetailsTotalsCellModel]()
        if !showTotals { return items }

        var totalSpent: String?
        var conversion: String?
        var ntwFees: String?
        var ntwFeesFiat: String?
        let receive = ""

        guard let amountObj: (String, Int64) = assetAmountList.amounts.first else {
            return items
        }
        let assetId = transaction.subaccount?.gdkNetwork.getFeeAsset() ?? "btc"
        if assetAmountList.amounts.count == 1 {
            let tSpent = abs(amountObj.1)
            if let balance = Balance.fromSatoshi(tSpent, assetId: amountObj.0) {
                let (amount, denom) = balance.toValue()
                let (fiat, fiatCurrency) = balance.toFiat()
                totalSpent = "\(amount) \(denom)"
                conversion = "\(fiat) \(fiatCurrency)".trimmingCharacters(in: .whitespaces)
            }
            if let balance = Balance.fromSatoshi(transaction.fee ?? 0, assetId: assetId) {
                let (amount, denom) = balance.toValue()
                ntwFees = "\(amount) \(denom)"
            }
            if let balance = Balance.fromSatoshi(transaction.fee ?? 0, assetId: assetId) {
                let (fiat) = balance.toFiatText()
                ntwFeesFiat = "\(fiat)"
            }
            if !AssetInfo.baseIds.contains(amountObj.0) {
                if let balance = Balance.fromSatoshi(tSpent, assetId: amountObj.0), let amount = Double(balance.fiat ?? ""), let feeBalance =  Balance.fromSatoshi(transaction.fee ?? 0, assetId: assetId), let fee = Double(feeBalance.fiat ?? ""), let feeCurr = feeBalance.fiatCurrency {
                    let totalFiat = amount + fee
                    totalSpent = "\(String(format: "%.2f", totalFiat)) \(feeCurr)"
                }
            }
        }
        if let totalSpent = totalSpent, let conversion = conversion, let ntwFees = ntwFees {
            items.append(TxDetailsTotalsCellModel(totalSpent: totalSpent,
                                                  conversion: conversion,
                                                  ntwFees: ntwFees,
                                                  ntwFeesFiat: ntwFeesFiat ?? "",
                                                  receive: receive,
                                                  assetId: amountObj.0,
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
            if let balance = Balance.fromSatoshi(transaction.fee ?? 0, assetId: transaction.subaccount?.gdkNetwork.getFeeAsset() ?? "btc") {
                let (amount, denom) = balance.toValue()
                let (fiat, fiatCurrency) = balance.toFiat()
                let str = "\(amount) \(denom) ≈ \(fiat) \(fiatCurrency)"

                items.append(TxDetailsInfoCellModel(title: "id_network_fees".localized, hint: str, type: .fee, hideBalance: hideBalance))
            }
        }

        // transaction Id
        if !transaction.isLightning {
            items.append(TxDetailsInfoCellModel(title: "id_transaction_id".localized,
                                                hint: transaction.hash ?? "",
                                                type: .txId,
                                                hideBalance: hideBalance))
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
        if swapId != nil {
            items.append(TxDetailsInfoCellModel(title: "Swap Id".localized,
                                                hint: swapId ?? "",
                                                type: .swapId,
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
        if transaction.isLightning {} else {
            models.append(
                TxDetailsActionCellModel(icon: UIImage(named: "ic_tx_action_explorer")!.maskWithColor(color: UIColor.gAccent()),
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
        return models
    }

    func showBumpFee() -> Bool {
        let subaccount =  WalletManager.current?.subaccounts.filter { $0.id == transaction.subaccountId }.first
        let showBumpFee = !transaction.isLiquid && transaction.canRBF && !(subaccount?.session?.isResetActive ?? false)
        return showBumpFee
    }

    func address(_ tx: Transaction) -> String? {
//        if tx.isLiquid {
//            return nil
//        }
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
    func getSwap() async throws -> BoltzSwap? {
        guard let hash = transaction.hash else {
            return nil
        }
        return try await BoltzController.shared.getSwap(txHash: hash)
    }
}
