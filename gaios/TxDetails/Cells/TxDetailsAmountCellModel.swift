import UIKit
import gdk

class TxDetailsAmountCellModel {

    var tx: Transaction
    var isLightning: Bool
    var id: String
    var value: Int64
    var hideBalance: Bool

    var iconSide: UIImage {
        value > 0 ? UIImage(named: "ic_tx_in")! : UIImage(named: "ic_tx_out")!
    }

    init(tx: Transaction,
         isLightning: Bool,
         id: String,
         value: Int64,
         hideBalance: Bool
    ) {
        self.tx = tx
        self.isLightning = isLightning
        self.id = id
        self.value = value
        self.hideBalance = hideBalance
    }
}
