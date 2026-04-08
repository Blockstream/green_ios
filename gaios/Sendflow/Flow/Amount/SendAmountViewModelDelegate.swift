import Foundation
import gdk

protocol SendAmountViewModelDelegate: AnyObject {
    @MainActor
    func sendAmountViewModel(_ vm: SendAmountViewModel, draft: TransactionDraft)
    @MainActor
    func sendAmountViewModel(_ vm: SendAmountViewModel, didFailWith error: Error)
}
