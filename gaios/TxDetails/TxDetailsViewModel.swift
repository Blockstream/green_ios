import UIKit
import gdk

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
                 "TxDetailsActionCell", "TxDetailsInfoCell"]
    
    private var hideBalance: Bool {
        return UserDefaults.standard.bool(forKey: AppStorage.hideBalance)
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
            TxDetailsAmountCellModel(tx: transaction,
                                     isLightning: wallet.type.lightning,
                                     id: $0.0,
                                     value: $0.1,
                                     hideBalance: hideBalance)
        }
    }

    var txDetailsInfoCellModels: [TxDetailsInfoCellModel] {
        
        var items = [TxDetailsInfoCellModel]()
        
        
        if transaction.type == .incoming || transaction.isRefundableSwap ?? false {} else {
            
            /// fee
            if let balance = Balance.fromSatoshi(transaction.fee, assetId: transaction.subaccountItem?.gdkNetwork.getFeeAsset() ?? "btc") {
                let (amount, denom) = balance.toValue()
                let (fiat, fiatCurrency) = balance.toFiat()
                let str = "\(amount) \(denom) ≈ \(fiat) \(fiatCurrency)"
                
                items.append(TxDetailsInfoCellModel(title: "Network fees".localized, hint: str, type: .fee, hideBalance: hideBalance))
            }
            
            /// fee rate
            if transaction.isLightning {} else {
                items.append(TxDetailsInfoCellModel(title: "id_fee_rate".localized, hint: "\(String(format: "%.2f satoshi / vbyte", Double(transaction.feeRate) / 1000))", type: .feeRate, hideBalance: hideBalance))
            }
        }
        
        /// address
        if let address = address(transaction) {
            
            var title = ""
            switch transaction.type {
            case .redeposit:
                title = "Redeposited to".localized
            case .incoming:
                title = "id_received_on".localized
            case .outgoing:
                title = "id_sent_to".localized
            case .mixed:
                title = "Swapped to".localized
            }
            
            let hint = address
            items.append(TxDetailsInfoCellModel(title: title,
                                                hint: hint,
                                                type: .address,
                                                hideBalance: hideBalance))
        }
        
        /// transaction Id
        if transaction.isLightning {} else {
            items.append(TxDetailsInfoCellModel(title: "id_transaction_id".localized,
                                                hint: transaction.hash ?? "",
                                                type: .txId,
                                                hideBalance: hideBalance))
        }
        
        /// note
        if !(transaction.memo ?? "").isEmpty {
            items.append(TxDetailsInfoCellModel(title: "id_note".localized,
                                                hint: transaction.memo ?? "",
                                                type: .memo,
                                                hideBalance: hideBalance))
        }
        
        
        /// message
        if transaction.isLightning && transaction.message != nil {
            items.append(TxDetailsInfoCellModel(title: "Message".localized,
                                                hint: transaction.message ?? "",
                                                type: .message,
                                                hideBalance: hideBalance))
        }
        /// url
        if transaction.isLightning && transaction.url != nil {
            let url = transaction.url ?? ("", "")
            items.append(TxDetailsInfoCellModel(title: url.0,
                                                hint: url.1,
                                                type: .url,
                                                hideBalance: hideBalance))
        }
        /// plaintext
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
                                         title: "Speed up Transaction".localized,
                                         action: .speedUp)
            )
        }
        if transaction.isLightning {} else {
            models.append(
                TxDetailsActionCellModel(icon: UIImage(named: "ic_tx_action_note")!,
                                         title: "Add Note".localized,
                                         action: .addNote)
            )
        }
        if (transaction.isLightning) {} else {
            models.append(
                TxDetailsActionCellModel(icon: UIImage(named: "ic_tx_action_explorer")!.maskWithColor(color: UIColor.gGreenMatrix()),
                                         title: "View in Explorer".localized,
                                         action: .explorer)
            )
        }
        if transaction.isLightning {} else {
            models.append(
                TxDetailsActionCellModel(icon: UIImage(named: "ic_tx_action_share")!,
                                         title: "Share Transaction".localized,
                                         action: .shareTx)
            )
        }
    
        if transaction.isLightning && !(transaction.isRefundableSwap ?? false) {
            models.append(
                TxDetailsActionCellModel(icon: UIImage(named: "ic_tx_action_more")!,
                                         title: "More Details".localized,
                                         action: .more)
            )
        }
        
        if transaction.isLightning && transaction.isRefundableSwap ?? false {
            models.append(
                TxDetailsActionCellModel(icon: UIImage(named: "ic_tx_action_revert")!.maskWithColor(color: UIColor.gGreenMatrix()),
                                         title: "Initiate Refund".localized,
                                         action: .refund)
            )
        }
        
        
        return models
    }

    func showBumpFee() -> Bool {
        let subaccount =  WalletManager.current?.subaccounts.filter { $0.hashValue == transaction.subaccount }.first
        let isWatchonly = WalletManager.current?.account.isWatchonly ?? false
        let showBumpFee = !transaction.isLiquid && transaction.canRBF && !isWatchonly && !(subaccount?.session?.isResetActive ?? false)
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
            let output = tx.outputs?.filter { $0["is_relevant"] as? Bool == false}.first
            return output?["address"] as? String
        case .incoming:
            let output = tx.outputs?.filter { $0["is_relevant"] as? Bool == true}.first
            return output?["address"] as? String
        default:
            return nil
        }
    }


}
