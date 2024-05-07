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
            list.append(TxDetailsMoreInfoCellModel(title: "Destination Public Key".localized,
                                       hint: destinationPubkey))
        }
        if let paymentHash = transaction.paymentHash {
            list.append(TxDetailsMoreInfoCellModel(title: "Payment Hash".localized,
                                                   hint: paymentHash))
        }
        if let paymentPreimage = transaction.paymentPreimage {
            list.append(TxDetailsMoreInfoCellModel(title: "Payment Pre Image".localized,
                                                   hint: paymentPreimage))
        }
        if let invoice = transaction.invoice {
            list.append(TxDetailsMoreInfoCellModel(title: "Invoice".localized,
                                                   hint: invoice))
        }

        if let fundingTxid = transaction.fundingTxid {
            list.append(TxDetailsMoreInfoCellModel(title: "Funding Transaction Id".localized,
                                                   hint: fundingTxid))
        }

        if let closingTxid = transaction.closingTxid {
            list.append(TxDetailsMoreInfoCellModel(title: "Closing Transaction Id".localized,
                                                   hint: closingTxid))
        }

        return list
    }
}
