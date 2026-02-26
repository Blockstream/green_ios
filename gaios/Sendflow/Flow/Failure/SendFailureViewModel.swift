import Foundation
import UIKit

@MainActor
final class SendFailureViewModel: Sendable {
    
    let delegate: SendFailureViewModelDelegate?
    let error: Error

    internal init(delegate: (any SendFailureViewModelDelegate)? = nil, error: any Error) {
        self.delegate = delegate
        self.error = error
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
}
