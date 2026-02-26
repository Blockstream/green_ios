import Foundation
import gdk

protocol SendLwkSignViewModelDelegate: AnyObject {
    @MainActor
    func didSendLwkSignViewModelWillSend(_ vm: SendLwkSignViewModel, transaction: gdk.Transaction)
    @MainActor
    func didSendLwkSignViewModelDidSend(_ vm: SendLwkSignViewModel)
    @MainActor
    func didSendLwkSignViewModelDidFailure(_ vm: SendLwkSignViewModel, error: Error)
}
