import Foundation
import UIKit
import core
import gdk
import LiquidWalletKit
import BreezSDK

enum SendRoute {
    case selectSubaccount(SendAccountAssetViewModel)
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

    private var draft: TransactionDraft?
    private var gdkTransaction: gdk.Transaction?
    private var sendTransactionSuccess: SendTransactionSuccess?
    private var sendHWViewController: SendHWViewController?
    private var sendSwapViewModel: SendSwapViewModel?
    private var swapPositionState: SwapPositionState?
    private var swapLockupResponse: LockupResponse?

    init(nav: UINavigationController, wallet: WalletDataModel, mainAccount: Account, onFinish: (() -> Void)?) {
        self.nav = nav
        self.wallet = wallet
        self.mainAccount = mainAccount
        self.onFinish = onFinish
    }

    func start(input: String?, subaccount: WalletItem?, assetId: String?) {
        let model = SendAddressViewModel(mainAccount: mainAccount, wallet: wallet, text: input, subaccount: subaccount, assetId: assetId, delegate: self)
        let vc = sendAddressViewController(model: model)
        nav.pushViewController(vc, animated: true)
    }
    
    func startSwap(subaccount: WalletItem?, assetId: String?) {
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
    
    func sendAmountViewController(model: SendAmountViewModel) -> SendAmountViewController? {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendAmountViewController") as? SendAmountViewController {
            vc.viewModel = model
            return vc
        }
        return nil
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
    func resolveSubaccounts(paymentTarget: PaymentTarget) -> [WalletItem] {
        guard let wallet = WalletManager.current else { return [] }
        switch paymentTarget {
        case .bitcoinAddress, .bip21, .psbt, .privateKey:
            return wallet.bitcoinSubaccountsWithFunds
        case .liquidAddress, .liquidBip21, .pset:
            return wallet.liquidSubaccountsWithFunds
        case .lightningInvoice:
            var subaccounts = wallet.liquidSubaccountsWithFunds
            if let ln = wallet.lightningSubaccount { subaccounts.append(ln) }
            return subaccounts
        case .lightningOffer, .lnUrl(_):
            if let subaccount = wallet.lightningSubaccount {
                return [subaccount]
            }
            return []
        default:
            return []
        }
    }

    func navigate(to route: SendRoute) async {
        if nav.presentedViewController != nil {
            await nav.dismissAsync(animated: true)
        }
        switch route {
        case .selectSubaccount(let model):
            let vc = sendAccountAssetViewController(model: model)
            nav.pushViewController(vc, animated: true)
        case .enterAmount(let model):
            if let vc = sendAmountViewController(model: model) {
                nav.pushViewController(vc, animated: true)
            }
        case .signAtomicSwap(let model):
            let vc = sendLwkSignViewController(model: model)
            nav.pushViewController(vc, animated: true)
        case .confirm(let model):
            if let vc = sendTxConfirmViewController(model: model) {
                await nav.presentAsync(vc, animated: true)
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
        case .bitcoinAddress, .bip21, .psbt, .bip353, .bip321:
            if draft.subaccount == nil {
                let model = sendAccountAssetViewModel(draft: draft)
                return .selectSubaccount(model)
            }
            let createTx = try TransactionBuilder.buildCreateTx(draft)
            let model = SendAmountViewModel(createTx: createTx)
            return .enterAmount(model)
        case .liquidAddress, .liquidBip21, .pset:
            if draft.subaccount == nil || draft.assetId == nil {
                let model = sendAccountAssetViewModel(draft: draft)
                return .selectSubaccount(model)
            }
            let createTx = try TransactionBuilder.buildCreateTx(draft)
            let model = SendAmountViewModel(createTx: createTx)
            return .enterAmount(model)
        case .lightningInvoice(let invoice):
            guard let subaccount = draft.subaccount else {
                let model = sendAccountAssetViewModel(draft: draft)
                return .selectSubaccount(model)
            }
            if subaccount.networkType.lightning {
                // send lightning tx
                let createTx = try TransactionBuilder.buildBreezCreateTx(input: invoice.description, subaccount: subaccount)
                if createTx.anyAmounts ?? false {
                    let model = SendAmountViewModel(createTx: createTx)
                    return .enterAmount(model)
                } else {
                    nav.topViewController?.startLoader(message: "")
                    let tx = try await TransactionBuilder.buildGdkTransactionFomBreez(lightningSubaccount: subaccount, createTx: createTx)
                    let model = SendTxConfirmViewModel(transaction: tx, subaccount: subaccount, denominationType: .Sats, isFiat: false, txType: .bolt11, unsignedPsbt: nil, signedPsbt: nil)
                    nav.topViewController?.stopLoader()
                    return .confirm(model)
                }
            } else {
                // bitcoin/liquid swap: open sign swap screen
                let xpub = AccountsRepository.shared.current?.xpubHashId
                let lwk = wallet.wallet.lwkSession
                guard let xpub, let lwk else {
                    throw SendFlowError.invalidSession
                }
                nav.topViewController?.startLoader(message: "")
                let (swap, tx) = try await TransactionBuilder.buildSubmarineSwapTransaction(invoice: invoice.description, lwk: lwk, subaccount: subaccount, xpub: xpub)
                var draft = draft
                draft.swapPayResponse = swap
                self.draft = draft
                let model = SendLwkSignViewModel(transactionDraft: draft, denominationType: .Sats, isFiat: false, subaccount: subaccount, delegate: self, tx: tx)
                nav.topViewController?.stopLoader()
                return .signAtomicSwap(model)
            }
        case .privateKey:
            if draft.subaccount == nil {
                let model = sendAccountAssetViewModel(draft: draft)
                return .selectSubaccount(model)
            }
            let createTx = try TransactionBuilder.buildCreateTx(draft)
            let model = SendAmountViewModel(createTx: createTx)
            return .enterAmount(model)
        case .lightningOffer, .lnUrl:
            // lightning tx
            guard draft.subaccount != nil else {
                let model = sendAccountAssetViewModel(draft: draft)
                return .selectSubaccount(model)
            }
            let createTx = try TransactionBuilder.buildCreateTx(draft)
            let model = SendAmountViewModel(createTx: createTx)
            return .enterAmount(model)
        }
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
        if let subaccount {
            if subaccountChain(subaccount) != paymentTarget.chain() && paymentTarget.chain() != .lightning {
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
            assetIdToUse = paymentAssetId
        }
        let draft = TransactionBuilder.buildTransactionDraft(
            paymentTarget: paymentTarget,
            subaccount: subaccountToUse,
            assetId: assetIdToUse)
        self.draft = draft
        Task { [weak self] in
            do {
                if let route = try await self?.route(draft: draft) {
                    await self?.navigate(to: route)
                }
            } catch {
                self?.nav.topViewController?.stopLoader()
                self?.forwardError(error)
            }
        }
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
        Task { [weak self] in
            do {
                if let route = try await self?.route(draft: draft) {
                    await self?.navigate(to: route)
                }
            } catch {
                self?.nav.topViewController?.stopLoader()
                self?.forwardError(error)
            }
        }
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
            let model = SendFailureViewModel(delegate: self, error: error)
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
                        from: SwapChainName.lightning.rawValue,
                        to: SwapChainName.liquid.rawValue)
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
                _ = try? await BoltzController.shared.create(id: nil, data: nil, isPending: false, xpubHashId: xpubHashId, invoice: invoice, swapType: .submarineSwap, txHash: sendTransactionSuccess.txHash)
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
            if let swapId = vm.swapId {
                Task { [weak wallet] in
                    if let persistentId = try? await BoltzController.shared.fetchID(byId: swapId) {
                        await wallet?.wallet.swapMonitor?.monitorSwap(id: persistentId)
                    }
                }
            }
            return .success(model)
        case .failure(let error):
            nav.topViewController?.stopLoader()
            let model = SendFailureViewModel(delegate: self, error: error)
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
        guard let subaccount = draft.subaccount else {
            forwardError(SendFlowError.failedToBuildTransaction)
            return
        }
        let model = SendLwkSignViewModel(transactionDraft: draft, denominationType: vm.currentState().denomination, isFiat: false, subaccount: subaccount, delegate: self, tx: gdkTransaction)
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
