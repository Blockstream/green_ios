import Foundation
import gdk

class TxDetailsMoreInfoViewModel {

    var transaction: Transaction

    init(transaction: Transaction) {
        self.transaction = transaction
    }

    var txDetailsMoreInfoCellModels: [TxDetailsMoreInfoCellModel] {
        
        var list: [TxDetailsMoreInfoCellModel] = []
        
        if let destinationPubkey = transaction.destinationPubkey?.1 {
            list.append(TxDetailsMoreInfoCellModel(title: "Destination Public Key".localized,
                                       hint: destinationPubkey))
        }
        if let paymentHash = transaction.paymentHash?.1 {
            list.append(TxDetailsMoreInfoCellModel(title: "Payment Hash".localized,
                                                   hint: paymentHash))
        }
        if let paymentPreimage = transaction.paymentPreimage?.1 {
            list.append(TxDetailsMoreInfoCellModel(title: "Payment Pre Image".localized,
                                                   hint: paymentPreimage))
        }
        if let invoice = transaction.invoice?.1 {
            list.append(TxDetailsMoreInfoCellModel(title: "Invoice".localized,
                                                   hint: invoice))
        }
        if let hash = transaction.hash {
            list.append(TxDetailsMoreInfoCellModel(title: "Invoice".localized,
                                                   hint: hash))
        }
        return list
    }
}
