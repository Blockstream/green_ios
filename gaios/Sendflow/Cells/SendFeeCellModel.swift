import Foundation
import core
import gdk

struct SendFeeCellModel {
    var speedName: String
    var time: String
    var amount: String
    var rate: String
    var fiat: String
    var error: String?
    var feeRate: UInt64?
    var transactionPriority: TransactionPriority
}
