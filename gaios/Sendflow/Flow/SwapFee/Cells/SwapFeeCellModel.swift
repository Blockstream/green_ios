import Foundation
import core
import gdk

struct SwapFeeCellModel {
    var speedName: String
    var time: String
    var feeRate: UInt64?
    var transactionPriority: TransactionPriority
}
