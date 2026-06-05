import Foundation
import UIKit
import core
import gdk
import LiquidWalletKit

enum ReceiveRoute {
    case editNote(String)
    case fundingFee
    case denominationSelector(DialogInputDenominationViewModel)
    case invoice(LNInvoiceViewModel)
    case addressAuth(AddressAuthViewModel)
    case manualBackup(ManualBackupViewModel)
    case send(subaccount: WalletItem, anyOrAsset: AnyOrAsset)
}

@MainActor
final class ReceiveCoordinator {
    private let nav: UINavigationController
    private let wallet: WalletDataModel
    private let mainAccount: Account
    private let onFinish: (() -> Void)?
    private var receiveViewModel: ReceiveViewModel?
    private var activeSendCoordinator: SendCoordinator?

    init(nav: UINavigationController, wallet: WalletDataModel, mainAccount: Account, onFinish: (() -> Void)?) {
        self.nav = nav
        self.wallet = wallet
        self.mainAccount = mainAccount
        self.onFinish = onFinish
    }
    func start(account: WalletItem, anyOrAsset: AnyOrAsset) {
        let model = ReceiveViewModel(mainAccount: mainAccount,
                                       walletDataModel: wallet,
                                       subaccount: account,
                                       anyOrAsset: anyOrAsset,
                                       delegate: self)
        let vc = receiveViewController(model: model)
        nav.pushViewController(vc, animated: true)
    }

    func navigate(to route: ReceiveRoute) async {
        if nav.presentedViewController != nil {
            await nav.dismissAsync(animated: true)
        }
        switch route {
        case .editNote(let description):
            let vc = dialogEditViewController(description)
            nav.present(vc, animated: false, completion: nil)
        case .fundingFee:
            let vc = dialogFundingFee()
            nav.present(vc, animated: false, completion: nil)
        case .denominationSelector(let model):
            let vc = dialogDenomination(model: model)
            nav.present(vc, animated: false, completion: nil)
        case .invoice(let model):
            let vc = invoiceController(model: model)
            nav.pushViewController(vc, animated: true)
        case .addressAuth(let model):
            let vc = addressAuthController(model: model)
            nav.pushViewController(vc, animated: true)
        case .manualBackup(let model):
            let vc = manualBackupController(model: model)
            nav.pushViewController(vc, animated: true)
        case .send(let subaccount, let anyOrAsset):
            activeSendCoordinator = SendCoordinator(nav: nav, wallet: wallet, mainAccount: mainAccount) { [weak self, weak nav] in
                nav?.popToRootViewController(animated: true)
                self?.activeSendCoordinator = nil
            }
            activeSendCoordinator?.start(input: nil, subaccount: subaccount, assetId: anyOrAsset.assetId)
        }
    }

    func receiveViewController(model: ReceiveViewModel) -> ReceiveViewController {
        let storyboard = UIStoryboard(name: "ReceiveFlow", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "ReceiveViewController") { coder in
            ReceiveViewController(coder: coder, viewModel: model)
        }
        vc.onFinish = { [weak self] in
            self?.receiveViewModel = nil
            self?.onFinish?()
        }
        return vc
    }
    func dialogEditViewController(_ description: String) -> DialogEditViewController {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "DialogEditViewController") { coder in
            DialogEditViewController(coder: coder, prefill: description)
        }
        vc.delegate = self
        vc.modalPresentationStyle = .overFullScreen
        return vc
    }
    func invoiceController(model: LNInvoiceViewModel) -> LNInvoiceViewController {
        let storyboard = UIStoryboard(name: "ReceiveFlow", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "LNInvoiceViewController") { coder in
            LNInvoiceViewController(coder: coder, viewModel: model)
        }
        return vc
    }
    func dialogFundingFee() -> DialogFundingFeeViewController {
        let storyboard = UIStoryboard(name: "ReceiveFlow", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "DialogFundingFeeViewController") { coder in
            DialogFundingFeeViewController(coder: coder)
        }
        // vc.delegate = self
        vc.modalPresentationStyle = .overFullScreen
        return vc
    }
    func dialogDenomination(model: DialogInputDenominationViewModel) -> DialogInputDenominationViewController {

        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "DialogInputDenominationViewController") { coder in
            DialogInputDenominationViewController(coder: coder, model: model)
        }
        vc.delegate = self
        vc.modalPresentationStyle = .overFullScreen
        return vc
    }
    func addressAuthController(model: AddressAuthViewModel) -> AddressAuthViewController {
        let storyboard = UIStoryboard(name: "AddressAuth", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "AddressAuthViewController") { coder in
            AddressAuthViewController(coder: coder, viewModel: model)
        }
        return vc
    }
    func manualBackupController(model: ManualBackupViewModel) -> ManualBackupViewController {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "ManualBackupViewController") { coder in
            ManualBackupViewController(coder: coder, viewModel: model)
        }
        return vc
    }
}

extension ReceiveCoordinator: ReceiveViewModelDelegate {
    func invoice(_ model: LNInvoiceViewModel) {
        Task { @MainActor in
            await navigate(to: .invoice(model))
        }
    }
    func editNote(vm: ReceiveViewModel, description: String) {
        receiveViewModel = vm
        Task { @MainActor in
            await navigate(to: .editNote(description))
        }
    }
    func fundingFee() {
        Task { @MainActor in
            await navigate(to: .fundingFee)
        }
    }
    func denominationSelector(vm: ReceiveViewModel, model: DialogInputDenominationViewModel) {
        receiveViewModel = vm
        Task { @MainActor in
            await navigate(to: .denominationSelector(model))
        }
    }
    func addressAuth(_ model: AddressAuthViewModel) {
        Task { @MainActor in
            await navigate(to: .addressAuth(model))
        }
    }
    func manualBackup(_ model: ManualBackupViewModel) {
        Task { @MainActor in
            await navigate(to: .manualBackup(model))
        }
    }
    func send(subaccount: gdk.WalletItem, anyOrAsset: AnyOrAsset) {
        Task { @MainActor in
            await navigate(to: .send(subaccount: subaccount, anyOrAsset: anyOrAsset))
        }
    }
}
extension ReceiveCoordinator: @MainActor DialogEditViewControllerDelegate {
    func didSave(_ note: String) {
        // pass the edited note back to receive view model
        receiveViewModel?.updateNote(note)
    }
    func didClose() {}
}
extension ReceiveCoordinator: @MainActor DialogInputDenominationViewControllerDelegate {
    func didSelectFiat() {
        receiveViewModel?.selectFiat()
    }
    func didSelectInput(denomination: gdk.DenominationType) {
        receiveViewModel?.selectDenomination(denomination)
    }
}
