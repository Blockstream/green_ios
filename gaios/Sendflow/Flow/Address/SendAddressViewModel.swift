import Foundation
import core
import gdk
import LiquidWalletKit
import greenaddress

@MainActor
final class SendAddressViewModel: Sendable {

    let wallet: WalletDataModel
    let text: String?
    let sweepPrivateKey: Bool
    let subaccount: WalletItem?
    let assetId: String?
    let delegate: SendAddressViewModelDelegate?

    private let parser = PaymentTargetParser()
    private var wm: WalletManager { wallet.wallet }
    
    // UI state
    var error: Error?
    var paymentTarget: PaymentTarget?
    var canContinue: Bool = false

    // Callback for UI updates
    var onStateChanged: (() -> Void)?

    init(
        wallet: WalletDataModel,
        text: String?,
        subaccount: WalletItem?,
        assetId: String?,
        sweepPrivateKey: Bool = false,
        delegate: SendAddressViewModelDelegate) {
        self.wallet = wallet
        self.text = text
        self.subaccount = subaccount
        self.assetId = assetId
        self.sweepPrivateKey = sweepPrivateKey
        self.delegate = delegate
    }

    func validate(text: String) async {
        error = nil
        paymentTarget = nil
        canContinue = false
        onStateChanged?()

        let task = Task { try await parser.parse(text) }
        switch await task.result {
        case .success(let type):
            paymentTarget = type
            canContinue = true
            delegate?.sendAddressViewModel(self, paymentTarget: type, subaccount: subaccount, assetId: assetId)
        case .failure(let error):
            if let error = error as? SendFlowError {
                delegate?.sendAddressViewModel(self, didFailWith: error)
            }
        }
        onStateChanged?()
    }

    func fundedSubaccounts() -> [WalletItem] {
        switch paymentTarget {
        case .bitcoinAddress, .bip21, .psbt, .privateKey:
            return wm.bitcoinSubaccountsWithFunds
        case .liquidAddress, .liquidBip21, .pset:
            return wm.liquidSubaccountsWithFunds
        case .lightningInvoice:
            var subaccounts = wm.bitcoinSubaccountsWithFunds + wm.liquidSubaccountsWithFunds
            if let subaccount = wm.lightningSubaccount {
                subaccounts += [subaccount]
            }
            return subaccounts
        case .lightningOffer, .lnUrl(_):
            if let subaccount = wm.lightningSubaccount {
                 return [subaccount]
            }
            return []
        default:
            return []
        }
    }

    func handleError(_ error: SendFlowError) {
        self.error = error
        canContinue = false
        onStateChanged?()
        delegate?.sendAddressViewModel(self, didFailWith: error)
    }
}
