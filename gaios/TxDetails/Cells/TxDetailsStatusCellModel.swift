import UIKit
import gdk

class TxDetailsStatusCellModel {

    var transaction: Transaction
    var blockHeight: UInt32
    var assetAmountList: AssetAmountList

    init(transaction: Transaction,
         blockHeight: UInt32,
         assetAmountList: AssetAmountList) {
        self.transaction = transaction
        self.blockHeight = blockHeight
        self.assetAmountList = assetAmountList
    }

    var txStatus: String {
        switch transaction.type {
        case .redeposit:
            return "id_redeposited".localized
        case .incoming:
            return "id_received".localized
        case .outgoing:
            return "id_sent".localized
        case .mixed:
            return "id_swapped".localized
        }
    }

    var txStatusExtended: String {

        switch transaction.type {
        case .redeposit:
            return "id_your_transaction_was".localized
        case .incoming:
            return "id_the_transaction_was".localized
        case .outgoing:
            return "id_your_transaction_was".localized
        case .mixed:
            return "id_your_transaction_was".localized
        }
    }

    var txUnconfirmedStatus: String {
        switch transaction.type {
        case .redeposit:
            return "id_redepositing".localized
        case .incoming:
            return "id_incoming".localized
        case .outgoing:
            return "id_outgoing".localized
        case .mixed:
            return "id_swapping".localized
        }
    }
}
