import Foundation
import gdk

protocol SendSwapFeeViewModelDelegate: AnyObject {
    @MainActor
    func sendSwapFeeViewModelDidSelect(_ vm: SendSwapFeeViewModel, transactionPriority: TransactionPriority, feeRate: UInt64)
    @MainActor
    func sendSwapFeeViewModelDismiss(_ vm: SendSwapFeeViewModel)
}
