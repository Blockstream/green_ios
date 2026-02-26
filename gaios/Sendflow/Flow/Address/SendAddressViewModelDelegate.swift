import Foundation
import gdk

protocol SendAddressViewModelDelegate: AnyObject {
    @MainActor
    func sendAddressViewModel(_ vm: SendAddressViewModel, paymentTarget: PaymentTarget, subaccount: WalletItem?, assetId: String?)
    @MainActor
    func sendAddressViewModel(_ vm: SendAddressViewModel, didFailWith error: Error)
}
