import Foundation
import UIKit

@MainActor
final class SendFailureViewModel: Sendable {

    let delegate: SendFailureViewModelDelegate?
    let error: Error
    let hideErrors: Bool

    internal init(delegate: (any SendFailureViewModelDelegate)? = nil,
                  error: any Error,
                  hideErrors: Bool) {
        self.delegate = delegate
        self.error = error
        self.hideErrors = hideErrors
    }

    func onDismiss() {
        delegate?.sendFailureViewModelDismiss(self)
    }

    func onRetry() {
        delegate?.sendFailureViewModelDidAgain(self)
    }

    func onSupport() {
        delegate?.sendFailureViewModelDidSupport(self, error: error)
    }
    func onOk() {
        delegate?.sendFailureViewModelOk(self)
    }
}
