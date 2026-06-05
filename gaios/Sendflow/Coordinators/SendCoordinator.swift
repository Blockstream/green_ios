import Foundation
import UIKit
import core
import gdk
import LiquidWalletKit

enum SendRoute {
    case selectSubaccount(SendAccountAssetViewModel)
    case enterLegacyAmount(SendAmountViewModelLegacy)
    case enterAmount(SendAmountViewModel)
    case signAtomicSwap(SendLwkSignViewModel)
    case confirm(SendTxConfirmViewModel)
    case success(SendSuccessViewModel)
    case failure(SendFailureViewModel)
    case support(ZendeskErrorRequest)
    case feeSelector(SendSwapFeeViewModel)
    case dialogSelectSubaccounts(DialogAccountsViewModel)
}

@MainActor
final class SendCoordinator {
    private let nav: UINavigationController
    private let onFinish: (() -> Void)?
    private let builder = TransactionBuilder()
    private let wallet: WalletDataModel
    private let mainAccount: Account
    private var selectedFiat: Bool = false
    private var selectedDenomination: DenominationType = .Sats

    private var draft: TransactionDraft?
    private var gdkTransaction: gdk.Transaction?
    private var sendTransactionSuccess: SendTransactionSuccess?
    private var sendHWViewController: SendHWViewController?
    private var sendSwapViewModel: SendSwapViewModel?
    private var swapPositionState: SwapPositionState?
    private var swapLockupResponse: LockupResponse?
    private var isRoutingInProgress = false

    init(nav: UINavigationController, wallet: WalletDataModel, mainAccount: Account, onFinish: (() -> Void)?) {
        self.nav = nav
        self.wallet = wallet
        self.mainAccount = mainAccount
        self.onFinish = onFinish
    }

    func start(input: String?, subaccount: WalletItem?, assetId: String?) {
        selectedDenomination = wallet.wallet.prominentSession?.settings?.denomination ?? .Sats
        let model = SendAddressViewModel(mainAccount: mainAccount, wallet: wallet, text: input, subaccount: subaccount, assetId: assetId, delegate: self)
        let vc = sendAddressViewController(model: model)
        nav.pushViewController(vc, animated: true)
    }

    func startSwap(subaccount: WalletItem?, assetId: String?) {
        selectedDenomination = wallet.wallet.prominentSession?.settings?.denomination ?? .Sats
        let model = SendSwapViewModel(wallet: wallet.wallet, subaccount: subaccount, assetId: assetId, delegate: self)
        let vc = sendSwapViewController(model: model)
        nav.pushViewController(vc, animated: true)
    }

    func sendLwkSignViewController(model: SendLwkSignViewModel) -> SendLwkSignViewController {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        return storyboard.instantiateViewController(identifier: "SendLwkSignViewController") { coder in
            SendLwkSignViewController(coder: coder, viewModel: model)
        }
    }

    func sendSwapViewController(model: SendSwapViewModel) -> SendSwapViewController {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        return storyboard.instantiateViewController(identifier: "SendSwapViewController") { coder in
            SendSwapViewController(coder: coder, viewModel: model)
        }
    }

    func sendAddressViewController(model: SendAddressViewModel) -> SendAddressViewController {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        return storyboard.instantiateViewController(identifier: "SendAddressViewController") { coder in
            SendAddressViewController(coder: coder, viewModel: model)
        }
    }
    func sendSuccessViewController(model: SendSuccessViewModel) -> SendSuccessViewController {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "SendSuccessViewController") { coder in
            SendSuccessViewController(coder: coder, viewModel: model)
        }
        vc.modalPresentationStyle = .overFullScreen
        return vc
    }

    func sendFailureViewController(model: SendFailureViewModel) -> SendFailureViewController {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "SendFailureViewController") { coder in
            SendFailureViewController(coder: coder, viewModel: model)
        }
        vc.modalPresentationStyle = .overFullScreen
        return vc
    }
    func sendSwapFeeViewController(model: SendSwapFeeViewModel) -> SendSwapFeeViewController {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "SendSwapFeeViewController") { coder in
            SendSwapFeeViewController(coder: coder, viewModel: model)
        }
        vc.modalPresentationStyle = .overFullScreen
        return vc
    }

    func sendHWViewController(model: SendHWViewModel) -> SendHWViewController {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "SendHWViewController") { coder in
            SendHWViewController(coder: coder, viewModel: model)
        }
        self.sendHWViewController = vc
        vc.modalPresentationStyle = .overFullScreen
        return vc
    }

    func contactUsViewController(request: ZendeskErrorRequest) -> ContactUsViewController? {
        let storyboard = UIStoryboard(name: "HelpCenter", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ContactUsViewController") as? ContactUsViewController {
            vc.request = request
            vc.modalPresentationStyle = .overFullScreen
            return vc
        }
        return nil
    }

    func sendAmountViewController(model: SendAmountViewModel) -> SendAmountViewController {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        return storyboard.instantiateViewController(identifier: "SendAmountViewController") { coder in
            SendAmountViewController(coder: coder, viewModel: model)
        }
    }
    func sendAmountViewControllerLegacy(model: SendAmountViewModelLegacy) -> SendAmountViewControllerLegacy {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        return storyboard.instantiateViewController(identifier: "SendAmountViewControllerLegacy") { coder in
            SendAmountViewControllerLegacy(coder: coder, viewModel: model)
        }
    }

    func sendTxConfirmViewController(model: SendTxConfirmViewModel) -> SendTxConfirmViewController? {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendTxConfirmViewController") as? SendTxConfirmViewController {
            vc.viewModel = model
            return vc
        }
        return nil
    }

    func sendAccountAssetViewController(model: SendAccountAssetViewModel) -> SendAccountAssetViewController {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        return storyboard.instantiateViewController(identifier: "SendAccountAssetViewController") { coder in
            SendAccountAssetViewController(coder: coder, viewModel: model)
        }
    }

    func dialogAccountsViewController(_ model: DialogAccountsViewModel) -> DialogAccountsViewController {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "DialogAccountsViewController") { coder in
            DialogAccountsViewController(coder: coder, viewModel: model)
        }
        vc.delegate = self
        vc.modalPresentationStyle = .overFullScreen
        return vc
    }

    func sendSwapFeeViewController(_ model: SendSwapFeeViewModel) -> SendSwapFeeViewController {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "SendSwapFeeViewController") { coder in
            SendSwapFeeViewController(coder: coder, viewModel: model)
        }
        vc.modalPresentationStyle = .overFullScreen
        return vc
    }
}
extension SendCoordinator {
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

    private func rail(for subaccount: WalletItem) -> PaymentRail? {
        if subaccount.networkType.liquid {
            return .liquid
        }
        if subaccount.networkType.lightning {
            return .lightning
        }
        if subaccount.networkType.bitcoin {
            return .bitcoin
        }
        return nil
    }

    func resolveSubaccounts(paymentTarget: PaymentTarget) -> [WalletItem] {
        guard let wallet = WalletManager.current else { return [] }
        let amount: UInt64? = {
            if case .lightningInvoice(let invoice) = paymentTarget {
                return invoice.amountMilliSatoshis()?.satoshi
            }
            return nil
        }()
        return paymentTarget
            .eligibleRails()
            .flatMap { subaccounts(for: $0, wallet: wallet, amount: amount) }
    }

    func navigate(to route: SendRoute) async {
        if nav.presentedViewController != nil {
            await nav.dismissAsync(animated: true)
        }
        switch route {
        case .selectSubaccount(let model):
            let vc = sendAccountAssetViewController(model: model)
            nav.pushViewController(vc, animated: true)
        case .enterLegacyAmount(let model):
            let vc = sendAmountViewControllerLegacy(model: model)
            nav.pushViewController(vc, animated: true)
        case .enterAmount(let model):
            let vc = sendAmountViewController(model: model)
            nav.pushViewController(vc, animated: true)
        case .signAtomicSwap(let model):
            let vc = sendLwkSignViewController(model: model)
            nav.pushViewController(vc, animated: true)
        case .confirm(let model):
            if let vc = sendTxConfirmViewController(model: model) {
                nav.pushViewController(vc, animated: true)
            }
        case .success(let model):
            let vc = sendSuccessViewController(model: model)
            await nav.presentAsync(vc, animated: true)
        case .failure(let model):
            let vc = sendFailureViewController(model: model)
            await nav.presentAsync(vc, animated: true)
        case .support(let request):
            if let vc = contactUsViewController(request: request) {
                await nav.presentAsync(vc, animated: true)
            }
        case .feeSelector(let model):
            let vc = sendSwapFeeViewController(model: model)
            await nav.presentAsync(vc, animated: true)
        case .dialogSelectSubaccounts(let model):
            let vc = dialogAccountsViewController(model)
            await nav.presentAsync(vc, animated: true)
        }
    }

    func sendAccountAssetViewModel(draft: TransactionDraft) -> SendAccountAssetViewModel {
        let accounts = resolveSubaccounts(paymentTarget: draft.paymentTarget!)
        return SendAccountAssetViewModel(
            subaccounts: accounts,
            draft: draft,
            wallet: wallet.wallet,
            delegate: self
        )
    }

    func route(draft: TransactionDraft) async throws -> SendRoute {
        guard let target = draft.paymentTarget else {
            throw SendFlowError.invalidPaymentTarget
        }
        switch target {
        case .bitcoinAddress, .bip21, .psbt, .bip321, .privateKey:
            if draft.subaccount == nil {
                return .selectSubaccount(sendAccountAssetViewModel(draft: draft))
            }
            let createTx = try TransactionBuilder.buildCreateTx(draft)
            return .enterLegacyAmount(SendAmountViewModelLegacy(createTx: createTx))
        case .liquidAddress, .liquidBip21, .pset:
            if draft.subaccount == nil || draft.assetId == nil {
                return .selectSubaccount(sendAccountAssetViewModel(draft: draft))
            }
            let createTx = try TransactionBuilder.buildCreateTx(draft)
            return .enterLegacyAmount(SendAmountViewModelLegacy(createTx: createTx))
        case .lightningInvoice(let invoice):
            guard let subaccount = draft.subaccount else {
                return .selectSubaccount(sendAccountAssetViewModel(draft: draft))
            }
            if invoice.amountMilliSatoshis() == nil && draft.satoshi == nil {
                return .enterAmount(makeEnterAmountViewModel(draft: draft, subaccount: subaccount))
            }
            if subaccount.networkType.lightning {
                return try await routeLightningInvoicePay(invoice, draft: draft, subaccount: subaccount)
            } else if subaccount.networkType.liquid {
                return try await routeLightningInvoiceSwap(invoice, draft: draft, subaccount: subaccount)
            } else {
                throw SendFlowError.wrongSubaccount
            }
        case .lightningOffer(let offer, let lightningPayment):
            guard let subaccount = draft.subaccount else {
                return .selectSubaccount(sendAccountAssetViewModel(draft: draft))
            }
            if subaccount.networkType.liquid {
                return try await routeLightningOffer(offer, lightningPayment: lightningPayment, draft: draft, subaccount: subaccount)
            } else {
                throw SendFlowError.wrongSubaccount
            }
        case .lnUrl(let input, let payment):
            guard let subaccount = draft.subaccount else {
                return .selectSubaccount(sendAccountAssetViewModel(draft: draft))
            }
            guard let amount = draft.satoshi, amount > 0 else {
                return .enterAmount(makeEnterAmountViewModel(draft: draft, subaccount: subaccount))
            }
            if subaccount.networkType.lightning {
                return try await routeLnUrlPay(
                    input,
                    payment: payment,
                    draft: draft,
                    subaccount: subaccount,
                    satoshi: amount
                )
            } else if subaccount.networkType.liquid {
                return try await routeLnUrlSwap(
                    input,
                    payment: payment,
                    draft: draft,
                    subaccount: subaccount,
                    satoshi: amount
                )
            } else {
                throw SendFlowError.wrongSubaccount
            }
        case .bip353(let original, let payment):
            return try await routeBip353(original, payment: payment, draft: draft)
        }
    }

    // BIP-353: resolve the DNS-based payment instruction, store the original
    // ₿-prefixed string on the draft for review-screen display, and re-enter
    // route(draft:) with the resolved target so existing handlers (BOLT11,
    // BOLT12, LNURL, on-chain) take over. The `LiquidWalletKit.Payment` is
    // built once in `PaymentTargetParser.mapPayment` and carried on the
    // `.bip353` case, so we don't re-parse the input here.
    private func routeBip353(
        _ original: String,
        payment: LiquidWalletKit.Payment,
        draft: TransactionDraft
    ) async throws -> SendRoute {
        let parser = PaymentTargetParser(mainAccount: mainAccount)
        let resolved = try await withRouteLoader(message: "Resolve DNS Payment") {
            try await parser.resolveBip353(original, payment: payment)
        }
        var updated = draft
        updated.paymentTarget = resolved
        updated.bip353Origin = original
        self.draft = updated
        return try await route(draft: updated)
    }
    // Liquid -> Lightning submarine swap. Bitcoin subaccounts are rejected.
    private func routeLightningInvoiceSwap(
        _ invoice: Bolt11Invoice,
        draft: TransactionDraft,
        subaccount: WalletItem
    ) async throws -> SendRoute {
        let xpub = AccountsRepository.shared.current?.xpubHashId
        let lwk = await wallet.wallet.awaitLwkSession()
        guard let xpub, let lwk else {
            throw SendFlowError.invalidSession
        }
        if !subaccount.networkType.liquid {
            throw SendFlowError.wrongSubaccount
        }
        guard let amount = invoice.amountMilliSatoshis()?.satoshi else {
            throw SendFlowError.generic("Invoice without amount not supported. Paste an invoice with an amount")
        }
        if let limits = try? await lwk.fetchSubmarineSwapsInfo()?.limits {
            let minimum = UInt64(limits.minimalBatched ?? limits.minimal)
            if amount < minimum {
                throw SendFlowError.invalidAmount(
                    "Min limit: \(minimum) sats"
                )
            }
            let maximum = UInt64(limits.maximal)
            if amount > maximum {
                throw SendFlowError.invalidAmount(
                    "Max limit: \(maximum) sats"
                )
            }
        }
        let lightningPayment = LightningPayment.fromBolt11Invoice(invoice: invoice)
        let (swap, tx) = try await withRouteLoader(message: "Preparing Payment") {
            try await TransactionBuilder.buildSubmarineSwapTransaction(
                lightningPayment: lightningPayment,
                lwk: lwk,
                subaccount: subaccount,
                xpub: xpub
            )
        }
        if let error = tx.error {
            if error == "id_insufficient_funds" {
                throw SendFlowError.insufficientFunds
            }
            throw SendFlowError.gdkError(error)
        }
        let preparedDraft = updateTransactionDraft(swap: swap, on: draft)
        return .signAtomicSwap(makeSignViewModel(draft: preparedDraft, subaccount: subaccount, tx: tx))
    }
    // BOLT11: native Lightning send on a Lightning subaccount
    private func routeLightningInvoicePay(
        _ invoice: Bolt11Invoice,
        draft: TransactionDraft,
        subaccount: WalletItem
    ) async throws -> SendRoute {
        let tx = try await withRouteLoader(message: "Preparing Payment") {
            try await TransactionBuilder.build(
                from: subaccount,
                invoice: invoice,
                satoshi: draft.satoshi)
        }
        if let error = tx.error {
            if error == "id_insufficient_funds" {
                throw SendFlowError.insufficientFunds
            }
            throw SendFlowError.gdkError(error)
        }
        return .signAtomicSwap(makeSignViewModel(draft: draft, subaccount: subaccount, tx: tx))
    }

    // BOLT12: Liquid-only submarine swap via LWK preparePay.
    // Lightning account attempts are rejected earlier with an LBTC-only error.
    private func routeLightningOffer(
        _ offer: String,
        lightningPayment: LightningPayment,
        draft: TransactionDraft,
        subaccount: WalletItem
    ) async throws -> SendRoute {
        guard subaccount.networkType.liquid else {
            throw SendFlowError.wrongSubaccount
        }
        var preparedDraft = updateTransactionDraft(
            satoshi: draft.satoshi,
            on: draft
        )
        // If the offer already carries an amount, always use it.
        if try lightningPayment.bolt12OfferHasAmount() {
            try lightningPayment.setBolt12InvoiceAmountViaItems(items: 1)
            if let offerAmount = try lightningPayment.bolt12InvoiceAmount(), offerAmount > 0 {
                preparedDraft = updateTransactionDraft(
                    satoshi: offerAmount,
                    on: draft
                )
            }
        } else {
            guard let satoshi = preparedDraft.satoshi, satoshi > 0 else {
                return .enterAmount(makeEnterAmountViewModel(draft: preparedDraft, subaccount: subaccount))
            }
            try lightningPayment.setBolt12InvoiceAmount(amountSats: satoshi)
        }
        let lwk = await wallet.wallet.awaitLwkSession()
        guard let lwk, let xpub = AccountsRepository.shared.current?.xpubHashId else {
            throw SendFlowError.invalidSession
        }
        let (swap, tx) = try await withRouteLoader(message: "Preparing Payment") {
            try await TransactionBuilder.buildSubmarineSwapTransaction(
                lightningPayment: lightningPayment,
                lwk: lwk,
                subaccount: subaccount,
                xpub: xpub
            )
        }
        if let error = tx.error {
            if error == "id_insufficient_funds" {
                throw SendFlowError.insufficientFunds
            }
            throw SendFlowError.gdkError(error)
        }
        preparedDraft = updateTransactionDraft(
            swap: swap,
            on: preparedDraft
        )
        return .signAtomicSwap(makeSignViewModel(draft: preparedDraft, subaccount: subaccount, tx: tx))
    }

    // LNURL: native Lightning resolves the invoice through the LN SDK
    private func routeLnUrlPay(
        _ input: String,
        payment: LiquidWalletKit.Payment,
        draft: TransactionDraft,
        subaccount: WalletItem,
        satoshi: UInt64
    ) async throws -> SendRoute {
        let tx = try await withRouteLoader(message: "Fetching Invoice..") {
            return try await TransactionBuilder.build(
                from: subaccount,
                lnurl: input,
                payment: payment,
                satoshi: satoshi)
        }
        if let error = tx.error {
            if error == "id_insufficient_funds" {
                throw SendFlowError.insufficientFunds
            }
            throw SendFlowError.gdkError(error)
        }
        return .signAtomicSwap(makeSignViewModel(draft: draft, subaccount: subaccount, tx: tx))
    }
    // Liquid it goes through the same LWK preparePay flow as BOLT12.
    private func routeLnUrlSwap(
        _ input: String,
        payment: LiquidWalletKit.Payment,
        draft: TransactionDraft,
        subaccount: WalletItem,
        satoshi: UInt64
    ) async throws -> SendRoute {
        let lwk = await wallet.wallet.awaitLwkSession()
        guard let lwk, let xpub = AccountsRepository.shared.current?.xpubHashId else {
            throw SendFlowError.invalidSession
        }
        let (swap, tx) = try await withRouteLoader(message: "Preparing Payment") {
            let lightningPayment = try await TransactionBuilder.resolveLnurlPayment(
                payment,
                amount: satoshi
            )
            return try await TransactionBuilder.buildSubmarineSwapTransaction(
                lightningPayment: lightningPayment,
                lwk: lwk,
                subaccount: subaccount,
                xpub: xpub
            )
        }
        if let error = tx.error {
            if error == "id_insufficient_funds" {
                throw SendFlowError.insufficientFunds
            }
            throw SendFlowError.gdkError(error)
        }
        let preparedDraft = updateTransactionDraft(
            swap: swap,
            on: draft
        )
        return .signAtomicSwap(makeSignViewModel(draft: preparedDraft, subaccount: subaccount, tx: tx))
    }

    private func withRouteLoader<T>(
        message: String = "",
        operation: () async throws -> T
    ) async throws -> T {
        nav.topViewController?.startLoader(message: message)
        defer {
            nav.topViewController?.stopLoader()
        }
        return try await operation()
    }

    private func makeEnterAmountViewModel(draft: TransactionDraft, subaccount: WalletItem) -> SendAmountViewModel {
        SendAmountViewModel(
            mainAccount: mainAccount,
            wallet: wallet,
            draft: draft,
            tx: nil,
            subaccount: subaccount,
            denominationType: selectedDenomination,
            isFiat: selectedFiat,
            delegate: self
        )
    }

    private func makeSignViewModel(
        draft: TransactionDraft,
        subaccount: WalletItem,
        tx: gdk.Transaction
    ) -> SendLwkSignViewModel {
        SendLwkSignViewModel(
            transactionDraft: draft,
            denominationType: selectedDenomination,
            isFiat: selectedFiat,
            subaccount: subaccount,
            delegate: self,
            tx: tx)
    }

    private func updateTransactionDraft(swap: PreparePayResponse? = nil, satoshi: UInt64? = nil, on draft: TransactionDraft) -> TransactionDraft {
        var updated = draft
        updated.swapPayResponse = swap ?? draft.swapPayResponse
        updated.satoshi = satoshi ?? draft.satoshi
        self.draft = updated
        return updated
    }
    func forwardError(_ error: Error?) {
        if let vc = nav.topViewController as? SendFlowErrorDisplayable {
            vc.handleSendFlowError(error)
        }
    }
    func forwardError(_ error: SendFlowError?) {
        if let vc = nav.topViewController as? SendFlowErrorDisplayable {
            vc.handleSendFlowError(error)
        }
    }

    func routeAndNavigate() {
        guard let draft else { return }
        if isRoutingInProgress {
            return
        }
        isRoutingInProgress = true
        Task { [weak self] in
            defer {
                self?.isRoutingInProgress = false
            }
            do {
                if let route = try await self?.route(draft: draft) {
                    await self?.navigate(to: route)
                }
            } catch {
                self?.forwardError(error)
            }
        }
    }

}
extension SendCoordinator: SendAddressViewModelDelegate {

    func sendAddressViewModel(_ vm: SendAddressViewModel, didFailWith error: Error) {
        forwardError(error)
    }
    func subaccountChain(_ subaccount: WalletItem) -> NetworkChainType {
        if subaccount.networkType.liquid {
            return NetworkChainType.liquid
        } else if subaccount.networkType.lightning {
            return NetworkChainType.lightning
        } else {
            return NetworkChainType.bitcoin
        }
    }
    func sendAddressViewModel(
        _ vm: SendAddressViewModel,
        paymentTarget: PaymentTarget,
        subaccount: gdk.WalletItem?,
        assetId: String?) {
        var subaccountToUse: WalletItem? = subaccount
        var assetIdToUse: AssetId? = assetId
        if !paymentTarget.eligibleRails().isEmpty &&
            resolveSubaccounts(paymentTarget: paymentTarget).isEmpty {
            let error: SendFlowError = {
                if case .lightningOffer = paymentTarget {
                    return .generic("Bolt12 payment is only available via LBTC")
                }
                if case .lightningInvoice(let invoice) = paymentTarget,
                   invoice.amountMilliSatoshis() == nil {
                    return .generic("Invoices without an amount can only be paid from a Lightning account")
                }
                return .noAvailableSubaccounts
            }()
            vm.delegate?.sendAddressViewModel(vm, didFailWith: error)
            return
        }
        if case .lightningOffer = paymentTarget, subaccountToUse?.networkType.lightning == true {
            vm.delegate?.sendAddressViewModel(vm, didFailWith: SendFlowError.generic("Bolt12 payment is only available via LBTC"))
            return
        }
        if let selected = subaccountToUse,
           let selectedRail = rail(for: selected),
           !paymentTarget.eligibleRails().contains(selectedRail) {
            subaccountToUse = nil
        }
        if case .lnUrl = paymentTarget {
            let eligibleSubaccounts = resolveSubaccounts(paymentTarget: paymentTarget)
            let hasLiquid = eligibleSubaccounts.contains { $0.networkType.liquid }
            let hasLightning = eligibleSubaccounts.contains { $0.networkType.lightning }
            // Preserve explicit upstream account selection (e.g. Home/Manage Asset).
            // Only force picker when no subaccount was preselected.
            if subaccount == nil && hasLiquid && hasLightning {
                subaccountToUse = nil
            }
        }
        if let subaccount = subaccountToUse {
            // BIP-353 resolves to any chain via DNS; defer chain validation to the
            // routing layer once we have the resolved target.
            let skipChainCheck: Bool = {
                if case .bip353 = paymentTarget { return true }
                return false
            }()
            if !skipChainCheck && subaccountChain(subaccount) != paymentTarget.chain() && paymentTarget.chain() != .lightning {
                vm.delegate?.sendAddressViewModel(vm, didFailWith: SendFlowError.wrongSubaccount)
                return
            }
        } else {
            let subaccounts = resolveSubaccounts(paymentTarget: paymentTarget)
            if subaccounts.isEmpty {
                // handle error: no available subaccounts
                vm.delegate?.sendAddressViewModel(vm, didFailWith: SendFlowError.noAvailableSubaccounts)
                return
            }
            if subaccounts.count == 1, let subaccount = subaccounts.first {
                subaccountToUse = subaccount
            }
        }
        if let paymentAssetId = paymentTarget.assetId() {
            if assetId != nil && assetId != paymentAssetId && paymentTarget.chain() != .lightning {
                let asset = wallet.wallet.info(for: paymentAssetId).ticker ?? paymentAssetId
                vm.delegate?.sendAddressViewModel(vm, didFailWith: SendFlowError.wrongAssetId(asset))
                return
            }
            if paymentTarget.chain() == .lightning, let subaccount = subaccountToUse {
                // For lightning-destination flows, the source rail determines displayed/spent asset.
                assetIdToUse = subaccount.networkType.liquid ? subaccount.gdkNetwork.getFeeAsset() : paymentAssetId
            } else {
                assetIdToUse = paymentAssetId
            }
        }
        let draft = TransactionBuilder.buildTransactionDraft(
            paymentTarget: paymentTarget,
            subaccount: subaccountToUse,
            assetId: assetIdToUse)
        self.draft = draft
        routeAndNavigate()
    }
}
extension SendCoordinator: SendAccountAssetViewModelDelegate {
    func didSelectAccountAsset(_ vm: SendAccountAssetViewModel, didFailWith error: Error) {
        forwardError(error)
    }

    func didSelectAccountAsset(_ vm: SendAccountAssetViewModel, subaccount: gdk.WalletItem, assetId: String?) {
        let updatedDraft = TransactionDraft.init(
            subaccount: subaccount,
            address: nil,
            satoshi: nil,
            assetId: assetId,
            sendAll: nil)
        draft = draft?.update(with: updatedDraft)
        guard let draft else {
            forwardError(SendFlowError.failedToBuildTransaction)
            return
        }
        routeAndNavigate()
    }
}
extension SendCoordinator: SendSuccessViewModelDelegate {
    func sendSuccessViewModelDidShare(_ vm: SendSuccessViewModel, url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        Task { await nav.presentAsync(activityVC, animated: true) }
    }

    func sendSuccessViewModelDidFinish(_ vm: SendSuccessViewModel) {
        StoreReviewHelper
            .shared
            .request(
                isSendAll: draft?.sendAll ?? false,
                account: AccountsRepository.shared.current,
                walletItem: draft?.subaccount)
        Task {
            await nav.dismissAsync(animated: true)
            onFinish?()
        }
    }
}

extension SendCoordinator: SendFailureViewModelDelegate {
    func sendFailureViewModelOk(_ vm: SendFailureViewModel) {
        Task {
            await nav.dismissAsync(animated: true)
            forwardError(nil)
        }
    }

    func sendFailureViewModelDismiss(_ vm: SendFailureViewModel) {
        Task {
            await nav.dismissAsync(animated: true)
            forwardError(nil)
        }
    }

    func sendFailureViewModelDidAgain(_ vm: SendFailureViewModel) {
        Task {
            await nav.dismissAsync(animated: true)
            forwardError(nil)
        }
    }

    func sendFailureViewModelDidSupport(_ vm: SendFailureViewModel, error: any Error) {
        Task {
            let request = ZendeskErrorRequest(
                error: error.description().localized,
                network: draft?.subaccount?.networkType,
                paymentHash: nil,
                shareLogs: true,
                screenName: "FailedTransaction")
            await navigate(to: .support(request))
        }
    }
}
extension SendCoordinator: SendLwkSignViewModelDelegate {
    func didSendLwkSignViewModelDidSend(_ vm: SendLwkSignViewModel) {
        guard let sendTransactionSuccess, let gdkTransaction else {
            let err = TransactionError.invalid(localizedDescription: "No transaction sent")
            didSendLwkSignViewModelDidFailure(vm, error: err)
            return
        }
        Task {
            let model = SendSuccessViewModel(
                sendTransactionSuccess: sendTransactionSuccess,
                tx: gdkTransaction,
                total: vm.convertToDenom(satoshi: vm.satoshiWithFee ?? 0),
                delegate: self)
            await self.navigate(to: .success(model))
        }
    }

    func didSendLwkSignViewModelDidFailure(_ vm: SendLwkSignViewModel, error: Error) {
        Task {
            let model = SendFailureViewModel(delegate: self, error: error, hideErrors: false)
            await self.navigate(to: .failure(model))
        }
    }

    func didSendLwkSignViewModelWillSend(_ vm: SendLwkSignViewModel, transaction: gdk.Transaction) {
        AnalyticsManager.shared.startSendTransaction()
        AnalyticsManager.shared.startFailedTransaction()
        let segment = AnalyticsManager.TransactionSegmentation(
            transactionType: .lwkSwap,
            addressInputType: .paste,
            sendAll: false)
        Task {
            let route = await handleSend(vm: vm, transaction: transaction)
            switch route {
            case .success(let model):
                AnalyticsManager.shared.endSendTransaction(
                    account: AccountsRepository.shared.current,
                    walletItem: transaction.subaccount,
                    transactionSgmt: segment,
                    withMemo: false)
                // Swap analytics must never be emitted for pure lightning payments.
                if vm.isSwapTransaction {
                    if vm.isCrossChainSwap {
                        let from = try vm.draft.lockupResponse?.chainFrom() ?? ""
                        let to = try vm.draft.lockupResponse?.chainTo() ?? ""
                        AnalyticsManager.shared.swapInternal(
                            account: AccountsRepository.shared.current,
                            from: from,
                            to: to)
                    } else if vm.isSubmarineSwap {
                        AnalyticsManager.shared.swapSend(
                            account: AccountsRepository.shared.current,
                            from: SwapChainName.liquid.rawValue,
                            to: SwapChainName.lightning.rawValue)
                    }
                }
                await navigate(to: route)
            case .failure(let model):
                AnalyticsManager.shared.failedTransaction(
                    account: AccountsRepository.shared.current,
                    walletItem: transaction.subaccount,
                    transactionSgmt: segment,
                    withMemo: false,
                    prettyError: model.error.description().localized,
                    nodeId: nil)
                await navigate(to: .failure(model))
            default:
                break
            }
        }
    }
    func handleSend(vm: SendLwkSignViewModel, transaction: gdk.Transaction) async -> SendRoute {
        nav.topViewController?.startLoader(message: "id_sending".localized)
        gdkTransaction = transaction
        if await wallet.mainAccount.isHW {
            let model = SendHWViewModel(
                tx: transaction,
                draft: draft,
                denomination: .Sats,
                subaccount: transaction.subaccount,
                isMultiAddressees: false,
                isQRMode: false)
            let vc = sendHWViewController(model: model)
            await nav.presentAsync(vc, animated: true)
        }
        let isJade = mainAccount.isJade
        let xpubHashId = mainAccount.xpubHashId
        let task = Task.detached {
            guard let subaccount = transaction.subaccount, var session = subaccount.session else {
                throw TransactionError.invalid(localizedDescription: "No subaccount selected")
            }
            if isJade {
                if let wm = BleHwManager.shared.walletManager, BleHwManager.shared.isConnected() && BleHwManager.shared.isLogged() {
                    session = wm.getSession(for: subaccount) ?? session
                }
            }
            let sendTransactionSuccess = try await TransactionBuilder.sendGdkTransaction(
                tx: transaction,
                session: session)
            if let swapId = vm.swapId, let persistentId = try? await BoltzController.shared.fetchID(byId: swapId) {
                try? await BoltzController.shared.update(with: persistentId, newTxHash: sendTransactionSuccess.txHash)
            } else if let invoice = try? vm.bolt11.description {
                // used magic routing to pay the invoice
                _ = try? await BoltzController.shared.create(id: String.random(length: 12), data: nil, isPending: false, xpubHashId: xpubHashId, invoice: invoice, swapType: .submarineSwap, txHash: sendTransactionSuccess.txHash)
            }
            return sendTransactionSuccess
        }
        switch await task.result {
        case .success(let sendTransactionSuccess):
            nav.topViewController?.stopLoader()
            self.sendTransactionSuccess = sendTransactionSuccess
            let model = SendSuccessViewModel(
                sendTransactionSuccess: sendTransactionSuccess,
                tx: transaction,
                total: vm.convertToDenom(satoshi: vm.satoshiWithFee ?? 0),
                delegate: self)
            if vm.isSwapTransaction, let swapId = vm.swapId {
                Task { [weak wallet] in
                    if let persistentId = try? await BoltzController.shared.fetchID(byId: swapId) {
                        await wallet?.wallet.swapMonitor?.monitorSwap(id: persistentId)
                    }
                }
            }
            return .success(model)
        case .failure(let error):
            nav.topViewController?.stopLoader()
            let model = SendFailureViewModel(delegate: self,
                                             error: error,
                                             hideErrors: transaction.subaccount?.networkType.lightning ?? false)
            return .failure(model)
        }
    }
}
extension SendCoordinator: SendSwapViewModelDelegate {
    func sendSwapViewModelWillSelectFee(_ vm: SendSwapViewModel, feeEstimator: FeeEstimator, priority: TransactionPriority, isLiquid: Bool) {
        sendSwapViewModel = vm
        let model = SendSwapFeeViewModel(feeEstimator: feeEstimator, priority: priority, isLiquid: isLiquid, delegate: self)
        Task { await navigate(to: .feeSelector(model)) }
    }
    func sendSwapViewModelWillSelectAccount(_ vm: SendSwapViewModel, model: DialogAccountsViewModel) {
        sendSwapViewModel = vm
        Task { await navigate(to: .dialogSelectSubaccounts(model)) }
    }
    func sendSwapViewModelDidTransaction(_ vm: SendSwapViewModel, draft: TransactionDraft, gdkTransaction: gdk.Transaction) {
        self.gdkTransaction = gdkTransaction
        self.draft = draft
        self.selectedFiat = vm.currentState().isFiat
        self.selectedDenomination = vm.currentState().denomination
        guard let subaccount = draft.subaccount else {
            forwardError(SendFlowError.failedToBuildTransaction)
            return
        }
        let model = SendLwkSignViewModel(
            transactionDraft: draft,
            denominationType: selectedDenomination,
            isFiat: selectedFiat,
            subaccount: subaccount,
            delegate: self,
            tx: gdkTransaction)
        Task { await navigate(to: .signAtomicSwap(model)) }
    }
    func sendSwapViewModelDidFail(_ vm: SendSwapViewModel, error: any Error) {
        forwardError(error)
    }
}
extension SendCoordinator: DialogAccountsViewControllerDelegate {
    func didSelectAccount(_ walletItem: gdk.WalletItem?) {
        if let subaccount = walletItem, let position = sendSwapViewModel?.selectedPosition {
            sendSwapViewModel?.updateAccount(account: subaccount, for: position)
        }
    }
}
extension SendCoordinator: SendSwapFeeViewModelDelegate {
    func sendSwapFeeViewModelDidSelect(_ vm: SendSwapFeeViewModel, transactionPriority: gdk.TransactionPriority, feeRate: UInt64) {
        sendSwapViewModel?.updatePriority(priority: transactionPriority, feeRate: feeRate)
    }
    func sendSwapFeeViewModelDismiss(_ vm: SendSwapFeeViewModel) {
        nav.dismiss(animated: true)
        nav.viewControllers.forEach { vc in
            if let sendSwapVC = vc as? SendSwapViewController {
                sendSwapVC.resumeEditing()
            }
        }
    }
}

extension SendCoordinator: SendAmountViewModelDelegate {
    func sendAmountViewModel(
        _ vm: SendAmountViewModel,
        didFailWith error: any Error) {
        forwardError(error)
    }

    func sendAmountViewModel(
        _ vm: SendAmountViewModel,
        draft: TransactionDraft) {
            self.draft = draft
            self.selectedFiat = vm.isFiat
            self.selectedDenomination = vm.denominationType
            guard (draft.subaccount != nil) else {
                forwardError(SendFlowError.failedToBuildTransaction)
                return
            }
            routeAndNavigate()
        }
}
