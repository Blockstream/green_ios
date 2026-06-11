import Foundation
import core

protocol SendLwkSignViewModelDelegate: AnyObject {
    @MainActor
    func didSendLwkSignViewModelWillSend(_ vm: SendLwkSignViewModel, transaction: Transaction)
    @MainActor
    func didSendLwkSignViewModelDidSend(_ vm: SendLwkSignViewModel)
    @MainActor
    func didSendLwkSignViewModelDidFailure(_ vm: SendLwkSignViewModel, error: Error)
}
