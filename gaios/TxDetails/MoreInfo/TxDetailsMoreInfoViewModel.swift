import Foundation
import gdk

class TxDetailsMoreInfoViewModel {

    var transaction: Transaction

    init(transaction: Transaction) {
        self.transaction = transaction
    }

    var txDetailsMoreInfoCellModels: [TxDetailsMoreInfoCellModel] {

        var list: [TxDetailsMoreInfoCellModel] = []

        if let destinationPubkey = transaction.destinationPubkey {
            list.append(TxDetailsMoreInfoCellModel(title: "id_destination_public_key".localized,
                                       hint: destinationPubkey))
        }
        if let paymentHash = transaction.paymentHash {
            list.append(TxDetailsMoreInfoCellModel(title: "id_payment_hash".localized,
                                                   hint: paymentHash))
        }
        if let paymentPreimage = transaction.paymentPreimage {
            list.append(TxDetailsMoreInfoCellModel(title: "id_payment_preimage".localized,
                                                   hint: paymentPreimage))
        }
        if let invoice = transaction.invoice {
            list.append(TxDetailsMoreInfoCellModel(title: "id_invoice".localized,
                                                   hint: invoice))
        }

        if let fundingTxid = transaction.fundingTxid {
            list.append(TxDetailsMoreInfoCellModel(title: "id_funding_transaction_id".localized,
                                                   hint: fundingTxid))
        }

        if let closingTxid = transaction.closingTxid {
            list.append(TxDetailsMoreInfoCellModel(title: "id_closing_transaction_id".localized,
                                                   hint: closingTxid))
        }

        return list
    }
}
