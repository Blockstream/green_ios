import Foundation
import gdk
import core

protocol SendSwapViewModelDelegate: AnyObject {
    @MainActor
    func sendSwapViewModelWillSelectAccount(_ vm: SendSwapViewModel, model: DialogAccountsViewModel)
    @MainActor
    func sendSwapViewModelWillSelectFee(_ vm: SendSwapViewModel, feeEstimator: FeeEstimator, priority: TransactionPriority, isLiquid: Bool)
    @MainActor
    func sendSwapViewModelDidTransaction(_ vm: SendSwapViewModel, draft: TransactionDraft, gdkTransaction: gdk.Transaction)
    @MainActor
    func sendSwapViewModelDidFail(_ vm: SendSwapViewModel, error: Error)
}
