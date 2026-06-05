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
    // `triggerNavigation` routes onto the next step on a successful parse.
    func validate(text: String, triggerNavigation: Bool = false) async {
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
            case .lnUrl(_, let payment):
                if isJadeCore() {
                    delegate?.sendAddressViewModel(self, didFailWith: SendFlowError.unsupportedInJadeCore)
                    onStateChanged?()
                    return
                }
                guard triggerNavigation else { break }
                do {
                    _ = try await Task.detached(priority: .userInitiated) {
                        try payment.resolveLnurlInfo()
                    }.value
                } catch {
                    self.handleError(SendFlowError.invalidPaymentTarget)
                    return
                }
            case .bip353(_, let payment):
                guard triggerNavigation else { break }
                do {
                    let resolved = try await Task.detached(priority: .userInitiated) {
                        try payment.resolveBip353()
                    }.value
                    if resolved.kind() == .bip353 {
                        throw SendFlowError.invalidPaymentTarget
                    }
                    if resolved.kind() == .lightningInvoice && isJadeCore() {
                        delegate?.sendAddressViewModel(self, didFailWith: SendFlowError.unsupportedInJadeCore)
                        onStateChanged?()
                        return
                    }
                    if resolved.kind() == .lnUrl {
                        if isJadeCore() {
                            delegate?.sendAddressViewModel(self, didFailWith: SendFlowError.unsupportedInJadeCore)
                            onStateChanged?()
                            return
                        }
                        _ = try await Task.detached(priority: .userInitiated) {
                            try resolved.resolveLnurlInfo()
                        }.value
                    }
                } catch {
                    self.handleError(SendFlowError.invalidPaymentTarget)
                    return
                }
            default:
                break
            }
            paymentTarget = type
            canContinue = true
            if triggerNavigation {
                delegate?.sendAddressViewModel(self, paymentTarget: type, subaccount: subaccount, assetId: assetId)
            }
        case .failure(let error):
            if let error = error as? SendFlowError {
                delegate?.sendAddressViewModel(self, didFailWith: error)
            }
        }
        onStateChanged?()
    }

    func fundedSubaccounts() -> [WalletItem] {
        guard let paymentTarget else { return [] }
        let amount: UInt64? = {
            if case .lightningInvoice(let invoice) = paymentTarget {
                return invoice.amountMilliSatoshis()?.satoshi
            }
            return nil
        }()
        return paymentTarget
            .eligibleRails()
            .flatMap { subaccounts(for: $0, wallet: wm, amount: amount) }
    }

    private func subaccounts(for rail: PaymentRail, wallet: WalletManager, amount: UInt64?) -> [WalletItem] {
        switch rail {
        case .bitcoin:
            return wallet.bitcoinSubaccountsWithFunds
        case .liquid:
            return wallet.liquidSubaccountsWithFunds
        case .lightning:
            if let subaccount = wallet.lightningSubaccount {
                let maxPayable = subaccount.lightningSession?.nodeState()?.maxPayableMsat.satoshi ?? 0
                if maxPayable > 0 {
                    if let amount = amount, maxPayable < amount {
                        return []
                    }
                    return [subaccount]
                }
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
