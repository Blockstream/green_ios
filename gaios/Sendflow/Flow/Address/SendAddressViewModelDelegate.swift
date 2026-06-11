import Foundation
import core

protocol SendAddressViewModelDelegate: AnyObject {
    @MainActor
    func sendAddressViewModel(_ vm: SendAddressViewModel, paymentTarget: PaymentTarget, subaccount: Account?, assetId: String?)
    @MainActor
    func sendAddressViewModel(_ vm: SendAddressViewModel, didFailWith error: Error)
}
