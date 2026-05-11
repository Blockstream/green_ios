import Foundation
import core
import gdk
import LiquidWalletKit
import greenaddress

@MainActor
final class SendAddressViewModel: Sendable {

    let wallet: WalletDataModel
    let mainAccount: Account
    let text: String?
    let sweepPrivateKey: Bool
    let subaccount: WalletItem?
    let assetId: String?
    let delegate: SendAddressViewModelDelegate?

    private let parser: PaymentTargetParser
    private var wm: WalletManager { wallet.wallet }
    
    // UI state
    var error: Error?
    var paymentTarget: PaymentTarget?
    var canContinue: Bool = false

    // Callback for UI updates
    var onStateChanged: (() -> Void)?

    init(
        mainAccount: Account,
        wallet: WalletDataModel,
        text: String?,
        subaccount: WalletItem?,
        assetId: String?,
        sweepPrivateKey: Bool = false,
        delegate: SendAddressViewModelDelegate
    ) {
        self.wallet = wallet
        self.text = text
        self.subaccount = subaccount
        self.assetId = assetId
        self.sweepPrivateKey = sweepPrivateKey
        self.delegate = delegate
        self.mainAccount = mainAccount
        self.parser = PaymentTargetParser(mainAccount: mainAccount)
    }
    func isJadeCore() -> Bool {
        if self.mainAccount.isJade {
            if self.mainAccount.boardType == .v2c {
                return true
            }
        }
        return false
    }
    func validate(text: String) async {
        error = nil
        paymentTarget = nil
        canContinue = false
        onStateChanged?()

        let task = Task { try await parser.parse(text) }
        switch await task.result {
        case .success(let type):
            switch type {
            case .lightningInvoice:
                if isJadeCore() {
                    delegate?.sendAddressViewModel(self, didFailWith: SendFlowError.unsupportedInJadeCore)
                    onStateChanged?()
                    return
                }
            default:
                break
            }
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
        guard let paymentTarget else { return [] }
        return paymentTarget
            .eligibleRails()
            .flatMap { subaccounts(for: $0, wallet: wm) }
    }

    private func subaccounts(for rail: PaymentRail, wallet: WalletManager) -> [WalletItem] {
        switch rail {
        case .bitcoin:
            return wallet.bitcoinSubaccountsWithFunds
        case .liquid:
            return wallet.liquidSubaccountsWithFunds
        case .lightning:
            if let subaccount = wallet.lightningSubaccount {
                return [subaccount]
            }
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
