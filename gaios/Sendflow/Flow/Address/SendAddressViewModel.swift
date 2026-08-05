import Foundation
import core

import LiquidWalletKit
import greenaddress

@MainActor
final class SendAddressViewModel: Sendable {

    let wallet: WalletDataModel
    let mainWallet: Wallet
    let text: String?
    let sweepPrivateKey: Bool
    let subaccount: Account?
    let assetId: String?
    let delegate: SendAddressViewModelDelegate?

    private let parser: PaymentTargetParser
    private var wm: WalletManager { wallet.wm }

    // UI state
    var error: Error?
    var paymentTarget: PaymentTarget?
    var canContinue: Bool = false

    // Callback for UI updates
    var onStateChanged: (() -> Void)?

    init(
        mainWallet: Wallet,
        wallet: WalletDataModel,
        text: String?,
        subaccount: Account?,
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
        self.mainWallet = mainWallet
        self.parser = PaymentTargetParser(mainWallet: mainWallet)
    }
    func isJadeCore() -> Bool {
        if self.mainWallet.isJade {
            if self.mainWallet.boardType == .v2c {
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
            case .lightningInvoice(let invoice):
                guard validateLightningInvoice(invoice) else { return }
            case .lnUrl(_, let payment):
                if isJadeCore() {
                    delegate?.sendAddressViewModel(self, didFailWith: SendFlowError.unsupportedInJadeCore)
                    onStateChanged?()
                    return
                }
                guard validateLiquidLightningPayment() else { return }
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
                    let resolvedTarget = try await parser.resolveBip353(text, payment: payment)
                    switch resolvedTarget {
                    case .lightningInvoice(let invoice):
                        guard validateLightningInvoice(invoice) else { return }
                    case .lightningOffer:
                        guard validateLightningOffer() else { return }
                    case .lnUrl(_, let resolvedPayment):
                        guard validateLiquidLightningPayment() else { return }
                        _ = try await Task.detached(priority: .userInitiated) {
                            try resolvedPayment.resolveLnurlInfo()
                        }.value
                    default:
                        break
                    }
                } catch SendFlowError.lbtcLightningPaymentsUnavailable {
                    handleError(.lbtcLightningPaymentsUnavailable)
                    return
                } catch {
                    self.handleError(SendFlowError.invalidPaymentTarget)
                    return
                }
            case .lightningOffer:
                guard validateLightningOffer() else { return }
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

    func fundedSubaccounts() -> [Account] {
        guard let paymentTarget else { return [] }
        let amount: UInt64? = {
            if case .lightningInvoice(let invoice) = paymentTarget {
                return invoice.amountMilliSatoshis()?.satoshi
            }
            return nil
        }()
        return paymentTarget
            .eligibleRails()
            .flatMap { subaccounts(for: $0, wm: wm, amount: amount) }
    }

    private func subaccounts(for rail: PaymentRail, wm: WalletManager, amount: UInt64?) -> [Account] {
        switch rail {
        case .bitcoin:
            return wm.bitcoinSubaccountsWithFunds()
        case .liquid:
            return wm.liquidSubaccountsWithFunds()
        case .lightning:
            if let subaccount = wm.glNetworkBackendOrNil()?.account {
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

    private func canPayNatively(_ invoice: Bolt11Invoice) -> Bool {
        guard let account = wm.glNetworkBackendOrNil()?.account else { return false }
        let maxPayable = account.lightningSession?.nodeState()?.maxPayableMsat.satoshi ?? 0
        guard maxPayable > 0 else { return false }
        guard let amount = invoice.amountMilliSatoshis()?.satoshi else { return true }
        return maxPayable >= amount
    }

    private func validateLightningInvoice(_ invoice: Bolt11Invoice) -> Bool {
        if isJadeCore() {
            delegate?.sendAddressViewModel(self, didFailWith: SendFlowError.unsupportedInJadeCore)
            onStateChanged?()
            return false
        }
        if subaccount?.networkId.liquid == true,
           !SwapAvailability.isCreationEnabled(.init(from: .liquid, to: .lightning)) {
            handleError(.lbtcLightningPaymentsUnavailable)
            return false
        }
        guard invoice.amountMilliSatoshis() != nil, !canPayNatively(invoice) else {
            return true
        }
        let error: SendFlowError = canPayWithLiquid(invoice) ?
            .lbtcLightningPaymentsUnavailable : .insufficientFunds
        handleError(error)
        return false
    }

    private func validateLightningOffer() -> Bool {
        if assetId == AssetInfo.lightningId || subaccount?.networkId.lightning == true {
            handleError(.generic("Bolt12 payment is only available via LBTC"))
            return false
        }
        return validateLiquidLightningPayment(liquidOnly: true)
    }

    private func validateLiquidLightningPayment(liquidOnly: Bool = false) -> Bool {
        let usesLiquid = liquidOnly || subaccount?.networkId.liquid == true
        guard usesLiquid,
              !SwapAvailability.isCreationEnabled(.init(from: .liquid, to: .lightning)) else {
            return true
        }
        handleError(.lbtcLightningPaymentsUnavailable)
        return false
    }

    private func canPayWithLiquid(_ invoice: Bolt11Invoice) -> Bool {
        guard let amount = invoice.amountMilliSatoshis()?.satoshi else { return false }
        return wm.liquidSubaccountsWithFunds().contains { account in
            let assetId = account.gdkNetwork.getFeeAsset()
            let balance = (try? account.assets(wm)[assetId]) ?? 0
            return balance >= 0 && UInt64(balance) >= amount
        }
    }

    func handleError(_ error: SendFlowError) {
        self.error = error
        canContinue = false
        onStateChanged?()
        delegate?.sendAddressViewModel(self, didFailWith: error)
    }
}
