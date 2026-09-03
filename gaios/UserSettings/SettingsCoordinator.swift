import Foundation
import UIKit
import core
import LiquidWalletKit

enum SettingsRoute {
    case recoveryTransactions(RecoveryTransactionsViewModel)
    case pgp(PgpViewModel)
    case learn2fa(Learn2faViewModel)
    case setEmailViewController(Set2FAViewModel)
    case setPhoneViewController(Set2FAViewModel)
    case setGauthViewController(Set2FAViewModel)
    case tfaLimit(TFALimitViewModel)
    case twoFactorAuth(TFAViewModel)
    case createAccount(CreateAccountViewModel)
    case archivedAccounts
    case watchonly(WatchOnlySettingsViewModel)
    case lightningDetails(LTDetailsViewModel)
    case lightningCreate(LTCreateViewModel)
    case amp(DialogAmpViewModel)
    case support(ZendeskErrorRequest)
    case jadeBoltzSwap(JadeBoltzSwapViewModel)
    case denominationExchange(DenominationExchangeViewModel)
    case autologout(DialogListViewModel)
    case rename
    case logout
}

@MainActor
final class SettingsCoordinator {
    private let nav: UINavigationController
    private let wallet: WalletDataModel
    private var mainWallet: Wallet
    private let onFinish: (() -> Void)?

    init(nav: UINavigationController, wallet: WalletDataModel, mainWallet: Wallet, onFinish: (() -> Void)?) {
        self.nav = nav
        self.wallet = wallet
        self.mainWallet = mainWallet
        self.onFinish = onFinish
    }

    func navigate(to route: SettingsRoute) {
        switch route {
        case .recoveryTransactions(let model):
            let vc = recoveryTransactionsViewController(model)
            nav.pushViewController(vc, animated: true)
        case .pgp(let model):
            let vc = pgpViewController(model)
            nav.pushViewController(vc, animated: true)
        case .learn2fa(let model):
            let vc = learn2faViewController(model)
            nav.pushViewController(vc, animated: true)
        case .setEmailViewController(let model):
            let vc = setEmailViewController(model)
            nav.pushViewController(vc, animated: true)
        case .setPhoneViewController(let model):
            let vc = setPhoneViewController(model)
            nav.pushViewController(vc, animated: true)
        case .setGauthViewController(let model):
            let vc = setGauthViewController(model)
            nav.pushViewController(vc, animated: true)
        case .tfaLimit(let model):
            let vc = twoFactorLimitViewController(model)
            nav.pushViewController(vc, animated: true)
        case .twoFactorAuth(let model):
            let vc = TFAViewController(model)
            nav.pushViewController(vc, animated: true)
        case .createAccount(let model):
            let vc = createAccountViewController(model)
            nav.pushViewController(vc, animated: true)
        case .archivedAccounts:
            let vc = accountArchiveViewController()
            nav.pushViewController(vc, animated: true)
        case .watchonly(let model):
            let vc = watchOnlySettingsViewController(model)
            nav.pushViewController(vc, animated: true)
        case .lightningDetails(let model):
            let vc = lightningDetailsViewController(model)
            nav.pushViewController(vc, animated: true)
        case .lightningCreate(let model):
            let vc = lightningCreateViewController(model)
            nav.pushViewController(vc, animated: true)
        case .amp(let model):
            let vc = dialogAmpViewController(model)
            vc.modalPresentationStyle = .overFullScreen
            nav.present(vc, animated: false, completion: nil)
        case .support(let request):
            nav.presentContactUsViewController(request: request, isPush: true)
        case .jadeBoltzSwap(let model):
            let vc = jadeBoltzSwapViewController(model)
            nav.pushViewController(vc, animated: true)
        case .denominationExchange(let model):
            let vc = denominationExchangeViewController(model)
            vc.modalPresentationStyle = .overFullScreen
            nav.present(vc, animated: true)
        case .autologout(let model):
            if let vc = dialogAutoLogoutViewController(model) {
                vc.modalPresentationStyle = .overFullScreen
                nav.present(vc, animated: false, completion: nil)
            }
        case .rename:
            if let vc = dialogRenameViewController() {
                vc.modalPresentationStyle = .overFullScreen
                nav.present(vc, animated: false, completion: nil)
            }
        case .logout:
            onFinish?()
        }
    }

    func pop() {
        nav.popViewController(animated: true)
    }

    func didCancelTwoFactorReset() {
        Task { [weak self] in
            await self?.wallet.triggerRefresh(features: [.alertCards, .settings])
        }
        pop()
    }

    var defaultMultisigNetworkId: NetworkId {
        wallet.wm.multisigNetworkIds.first {
            wallet.wm.gdkNetworkBackendOrNil($0)?.isLoggedIn == true
        } ?? wallet.wm.bitcoinMultisigNetworkId
    }

    func tfaViewModel() -> TFAViewModel {
        TFAViewModel(mainWallet: mainWallet, wm: wallet.wm)
    }

    func pgpViewModel(networkId: NetworkId? = nil) -> PgpViewModel {
        PgpViewModel(
            mainWallet: mainWallet,
            manager: wallet.wm,
            networkId: networkId ?? defaultMultisigNetworkId
        )
    }

    func watchOnlySettingsViewModel() -> WatchOnlySettingsViewModel {
        WatchOnlySettingsViewModel()
    }

    func createAccountViewModel() -> CreateAccountViewModel {
        CreateAccountViewModel()
    }

    func jadeBoltzSwapViewModel() -> JadeBoltzSwapViewModel {
        JadeBoltzSwapViewModel(wm: wallet.wm, mainWallet: mainWallet)
    }

    func set2FAViewModel(
        networkId: NetworkId? = nil,
        method: TwoFactorType,
        isSetRecovery: Bool = false,
        isSmsBackup: Bool = false
    ) -> Set2FAViewModel {
        Set2FAViewModel(
            mainWallet: mainWallet,
            manager: wallet.wm,
            networkId: networkId ?? defaultMultisigNetworkId,
            method: method,
            isSetRecovery: isSetRecovery,
            isSmsBackup: isSmsBackup
        )
    }

    func lightningDetailsViewModel() -> LTDetailsViewModel? {
        guard let lightningSession = wallet.wm.lightningSession else { return nil }
        return LTDetailsViewModel(lightningSession: lightningSession)
    }

    func lightningCreateViewModel() -> LTCreateViewModel {
        LTCreateViewModel(mainWallet: mainWallet, wallet: wallet)
    }

    func dialogAmpViewModel() -> DialogAmpViewModel {
        let wallet = self.wallet
        return DialogAmpViewModel { _ in
            Task {
                await wallet.triggerRefresh(features: [.subaccounts, .settings, .balance])
            }
        }
    }

    func hasLightning() -> Bool {
        AuthenticationTypeHandler.findAuth(
            method: .AuthKeyLightning,
            forNetwork: mainWallet.keychainLightning
        )
    }

    func recoveryTransactionsViewModel(networkId: NetworkId) -> RecoveryTransactionsViewModel {
        return RecoveryTransactionsViewModel(
            mainWallet: mainWallet,
            manager: wallet.wm,
            networkId: networkId
        )
    }

    func recoveryTransactionsViewController(_ model: RecoveryTransactionsViewModel) -> RecoveryTransactionsViewController {
        let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "RecoveryTransactionsViewController") { coder in
            gaios
                .RecoveryTransactionsViewController(
                    coder: coder,
                    viewModel: model
                )
        }
        vc.coordinator = self
        return vc
    }

    func learn2faViewModel(networkId: NetworkId, message: TwoFactorResetMessage) -> Learn2faViewModel {
        return Learn2faViewModel(
            mainWallet: mainWallet,
            manager: wallet.wm,
            networkId: networkId,
            message: message
        )
    }
    func learn2faViewController(_ model: Learn2faViewModel) -> Learn2faViewController {
        let storyboard = UIStoryboard(name: "Wallet", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "Learn2faViewController") { coder in
            Learn2faViewController(coder: coder, viewModel: model)
        }
        vc.delegate = self
        vc.coordinator = self
        return vc
    }

    func tfaLimitViewModel(networkId: NetworkId) -> TFALimitViewModel {
        return TFALimitViewModel(
            mainWallet: mainWallet,
            wm: wallet.wm,
            networkId: networkId
        )
    }

    func twoFactorLimitViewController(_ model: TFALimitViewModel) -> TwoFactorLimitViewController {
        let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "TwoFactorLimitViewController") { coder in
            TwoFactorLimitViewController(coder: coder, viewModel: model)
        }
        vc.coordinator = self
        return vc
    }

    func setEmailViewController(_ model: Set2FAViewModel) -> SetEmailViewController {
        let storyboard = UIStoryboard(name: "AuthenticatorFactors", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "SetEmailViewController") { coder in
            SetEmailViewController(coder: coder, viewModel: model)
        }
        vc.coordinator = self
        return vc
    }

    func setPhoneViewController(_ model: Set2FAViewModel) -> SetPhoneViewController {
        let storyboard = UIStoryboard(name: "AuthenticatorFactors", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "SetPhoneViewController") { coder in
            SetPhoneViewController(coder: coder, viewModel: model)
        }
        vc.coordinator = self
        return vc
    }

    func setGauthViewController(_ model: Set2FAViewModel) -> SetGauthViewController {
        let storyboard = UIStoryboard(name: "AuthenticatorFactors", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "SetGauthViewController") { coder in
            SetGauthViewController(coder: coder, viewModel: model)
        }
        vc.coordinator = self
        return vc
    }

    func pgpViewController(_ model: PgpViewModel) -> PgpViewController {
        let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "PgpViewController") { coder in
            PgpViewController(coder: coder, viewModel: model)
        }
        return vc
    }

    func accountArchiveViewController() -> AccountArchiveViewController {
        let storyboard = UIStoryboard(name: "Accounts", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "AccountArchiveViewController") { coder in
            AccountArchiveViewController(coder: coder)
        }
        vc.delegate = self
        return vc
    }

    func createAccountViewController(_ model: CreateAccountViewModel) -> CreateAccountViewController {
        let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "CreateAccountViewController") { coder in
            CreateAccountViewController(coder: coder, viewModel: model)
        }
        vc.delegate = self
        return vc
    }

    func lightningDetailsViewController(_ model: LTDetailsViewModel) -> LTDetailsViewController {
        let storyboard = UIStoryboard(name: "LTFlow", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "LTDetailsViewController") { coder in
            LTDetailsViewController(coder: coder, viewModel: model)
        }
        return vc
    }

    func lightningCreateViewController(_ model: LTCreateViewModel) -> LTCreateViewController {
        let storyboard = UIStoryboard(name: "LTFlow", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "LTCreateViewController") { coder in
            LTCreateViewController(coder: coder, viewModel: model)
        }
        return vc
    }

    func TFAViewController(_ model: TFAViewModel) -> TFAViewController {
        let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "TFAViewController") { coder in
            gaios.TFAViewController(coder: coder, viewModel: model)
        }
        vc.delegate = self
        vc.coordinator = self
        return vc
    }

    func dialogAmpViewController(_ model: DialogAmpViewModel) -> DialogAmpViewController {
        let storyboard = UIStoryboard(name: "AmpFlow", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "DialogAmpViewController") { coder in
            DialogAmpViewController(coder: coder, model: model)
        }
        return vc
    }

    func denominationExchangeViewModel() -> DenominationExchangeViewModel {
        DenominationExchangeViewModel(
            mainWallet: mainWallet,
            manager: wallet.wm
        )
    }

    func denominationExchangeViewController(_ model: DenominationExchangeViewModel) -> DenominationExchangeViewController {
        let storyboard = UIStoryboard(name: "DenominationExchangeFlow", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "DenominationExchangeViewController") { coder in
            DenominationExchangeViewController(coder: coder, viewModel: model)
        }
        vc.delegate = self
        return vc
    }

    func jadeBoltzSwapViewController(_ model: JadeBoltzSwapViewModel) -> JadeBoltzSwapViewController{
        let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "JadeBoltzSwapViewController") { coder in
            JadeBoltzSwapViewController(coder: coder, viewModel: model)
        }
        vc.delegate = self
        return vc
    }
    func watchOnlySettingsViewController(_ model: WatchOnlySettingsViewModel) -> WatchOnlySettingsViewController {
        let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "WatchOnlySettingsViewController") { coder in
            WatchOnlySettingsViewController(coder: coder, viewModel: model)
        }
        return vc
    }

    func dialogRenameViewController() -> DialogRenameViewController? {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogRenameViewController") as? DialogRenameViewController {
            vc.delegate = self
            vc.index = nil
            vc.prefill = mainWallet.name
            return vc
        }
        return nil
    }

    func selectAutoLogout(autolock: AutoLockType) async throws {
        guard var settings = await wallet.wm.settings else { return }
        settings.autolock = autolock
        try await wallet.wm.prominentNetworkBackend?.changeSettings(settings)
        await wallet.triggerRefresh(features: [.settings])
    }

    func dialogAutoLogoutViewModel() -> DialogListViewModel? {
        let list = [AutoLockType.minute.string, AutoLockType.twoMinutes.string, AutoLockType.fiveMinutes.string, AutoLockType.tenMinutes.string, AutoLockType.sixtyMinutes.string]
        return DialogListViewModel(
            title: "id_auto_logout_timeout".localized,
            type: .autoLogoutPrefs,
            items: list
                .enumerated()
                .map { index, element in AutoLogoutCellModel(
                    title: element,
                    index: index,
                    selected: element == (wallet.wm.settings?.autolock ?? .fiveMinutes).string,
                    onSelected: { [weak self] index in
                        let autolock = AutoLockType.from(list[index])
                        Task { [weak self] in
                            self?.nav.startAnimating()
                            do {
                                try await self?.selectAutoLogout(autolock: autolock)
                                await MainActor.run {
                                    self?.nav.stopAnimating()
                                    self?.nav.dismiss(animated: true)
                                }
                            } catch {
                                self?.nav.stopAnimating()
                                self?.nav.topViewController?.showError(error)
                            }
                        }
                    }
                )
                })
    }

    func dialogAutoLogoutViewController(_ model: DialogListViewModel) -> DialogListViewController? {
        let dialogStoryboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let dialogViewController = dialogStoryboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {
            dialogViewController.viewModel = model
            return dialogViewController
        }
        return nil
    }
}

extension SettingsCoordinator: DialogWatchOnlySetUpViewControllerDelegate {
    func watchOnlyDidUpdate(_ action: WatchOnlySetUpAction) {
        switch action {
        case .save, .delete:
            Task { [weak self] in
                await self?.wallet.triggerRefresh(features: [.settings])
            }
        default:
            break
        }
    }
}

extension SettingsCoordinator: DenominationExchangeViewControllerDelegate {
    func onDenominationExchangeSave() {
        Task { [weak self] in
            await self?.wallet
                .triggerRefresh(
                    features: [.balance, .txs(reset: true), .priceChart]
                )
        }
    }
}

extension SettingsCoordinator: AccountArchiveViewControllerDelegate {
    func archiveDidChange() {
        Task { [weak self] in
            await self?.wallet.triggerRefresh(features: [.subaccounts])
            await self?.wallet
                .triggerRefresh(
                    features: [.balance, .txs(reset: true)]
                )
        }
    }
}

extension SettingsCoordinator: CreateAccountDelegate {
    func didCreateAccount() {
        refreshAfterAccountChange()
    }

    func didUnarchiveAccount() {
        refreshAfterAccountChange()
    }

    private func refreshAfterAccountChange() {
        Task { [weak self] in
            await self?.wallet.triggerRefresh(features: [.subaccounts])
            await self?.wallet.triggerRefresh(features: [.settings, .balance, .txs(reset: true)])
        }
    }
}

extension SettingsCoordinator: TFAViewControllerDelegate {
    func sendLogout() {
        onFinish?()
    }
}

extension SettingsCoordinator: Learn2faViewControllerDelegate {
    func userLogout() {
        onFinish?()
    }
}

extension SettingsCoordinator: DialogRenameViewControllerDelegate {

    func didRename(name: String, index: String?) {
        mainWallet.name = name
        WalletsStorage.shared.upsert(mainWallet)
        Task { [weak self] in
            guard let self else { return }
            await self.wallet.updateMainWallet(self.mainWallet)
            await self.wallet.triggerRefresh(features: [.subaccounts])
            await self.wallet.triggerRefresh(features: [.settings, .balance, .txs(reset: true)])
        }
    }
    func didCancel() {
    }
}

extension SettingsCoordinator: JadeBoltzSwapViewControllerDelegate {
    func onSwapsUpdated() {
        Task { [weak self] in
            await self?.wallet.triggerRefresh(features: [.settings])
        }
    }
}
