import Foundation
import core
import gdk
import greenaddress
import UIKit

@MainActor
final class SendSwapFeeViewModel {
    private let feeEstimator: FeeEstimator
    private let delegate: SendSwapFeeViewModelDelegate
    let isLiquid: Bool
    var priority: TransactionPriority
    let priorities: [TransactionPriority] = [.High, .Medium, .Low]

    init(feeEstimator: FeeEstimator, priority: TransactionPriority, isLiquid: Bool, delegate: SendSwapFeeViewModelDelegate) {
        self.feeEstimator = feeEstimator
        self.priority = priority
        self.isLiquid = isLiquid
        self.delegate = delegate
    }

    func minFeeRate() -> UInt64? {
        feeEstimator.defaultMinFee
    }
    func feeRate(at: TransactionPriority) -> UInt64? {
        feeEstimator.feeRate(at: at)
    }

    func select(priority: TransactionPriority, feeRate: UInt64) {
        delegate.sendSwapFeeViewModelDidSelect(self, transactionPriority: priority, feeRate: feeRate)
    }

    func dismiss() {
        delegate.sendSwapFeeViewModelDismiss(self)
    }
}
