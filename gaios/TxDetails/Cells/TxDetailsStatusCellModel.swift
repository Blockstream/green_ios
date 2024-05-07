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

        let str = "Your transaction was successfully" + " "
        switch transaction.type {
        case .redeposit:
            return str + "id_redeposited".localized.lowercased()
        case .incoming:
            return str + "id_received".localized.lowercased()
        case .outgoing:
            return str + "id_sent".localized.lowercased()
        case .mixed:
            return str + "id_swapped".localized.lowercased()
        }
    }

    var txUnconfirmedStatus: String {
        switch transaction.type {
        case .redeposit:
            return "Redepositing".localized
        case .incoming:
            return "id_incoming".localized
        case .outgoing:
            return "id_outgoing".localized
        case .mixed:
            return "Swapping".localized
        }
    }
}
