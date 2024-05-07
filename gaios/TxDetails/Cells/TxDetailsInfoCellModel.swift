import UIKit
import gdk

enum TxDetailsInfoType {
    case fee
    case feeRate
    case address
    case txId
    case memo
    case message
    case url
    case plaintext
}

class TxDetailsInfoCellModel {

    var title: String
    var hint: String
    var type: TxDetailsInfoType
    var hideBalance: Bool

    init(title: String,
         hint: String,
         type: TxDetailsInfoType,
         hideBalance: Bool
    ) {
        self.title = title
        self.hint = hint
        self.type = type
        self.hideBalance = hideBalance
    }
}
