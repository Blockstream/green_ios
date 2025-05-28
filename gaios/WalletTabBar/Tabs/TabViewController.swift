import UIKit
import gdk
import core

enum TabHomeSection: Int, CaseIterable {
    case header
    case balance
    case backup
    case card
    case assets
    case chart
    case promo
}
enum TabTransactSection: Int, CaseIterable {
    case header
    case balance
    case actions
    case transactions
}
enum TabSecuritySection: Int, CaseIterable {
    case header
    case level
    case jade
    case backup
    case unlock
    case recovery
}
enum TabSettingsSection: Int, CaseIterable {
    case header
    case general
    case wallet
    case twoFactor
    case about
}

class TabViewController: UIViewController {

    var sectionHeaderH: CGFloat = 54.0
    var footerH: CGFloat = 54.0

    var walletModel: WalletModel {
        // swiftlint:disable force_cast
        let mainTab = parent as! WalletTabBarViewController
        return mainTab.walletModel
    }

    var walletTab: WalletTabBarViewController {
        // swiftlint:disable force_cast
        parent as! WalletTabBarViewController
    }
}
extension TabViewController {

    func buyScreen(_ walletModel: WalletModel) {
        AnalyticsManager.shared.buyInitiate(account: AccountsRepository.shared.current)
        
        if !self.walletTab.getCountlyRemoteConfigEnableBuyIosUk() && self.walletTab.checkUKRegion() {
            showAlert(title: "Buy Bitcoin".localized, message: "Feature unavailable in the UK. Coming soon.")
            return
        }
        let storyboard = UIStoryboard(name: "BuyBTCFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "BuyBTCViewController") as? BuyBTCViewController {
            vc.viewModel = BuyBTCViewModel(
                currency: walletModel.currency,
                hideBalance: walletModel.hideBalance)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func sendScreen(_ walletModel: WalletModel) {
        let sendAddressInputViewModel = SendAddressInputViewModel(
            input: nil,
            preferredAccount: ReceiveViewModel.defaultAccount,
            txType: walletModel.isSweepEnabled() ? .sweep : .transaction)

        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendAddressInputViewController") as? SendAddressInputViewController {
            vc.viewModel = sendAddressInputViewModel
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func txScreen(_ tx: Transaction) {
        let storyboard = UIStoryboard(name: "TxDetails", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "TxDetailsViewController") as? TxDetailsViewController, let wallet = tx.subaccount {
            vc.vm = TxDetailsViewModel(wallet: wallet, transaction: tx)
            vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func receiveScreen(_ walletModel: WalletModel) {
        let storyboard = UIStoryboard(name: "Wallet", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ReceiveViewController") as? ReceiveViewController {
            vc.viewModel = ReceiveViewModel()
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func accountsScreen(model: DialogAccountsViewModel) {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogAccountsViewController") as? DialogAccountsViewController {
            vc.viewModel = model
            vc.modalPresentationStyle = .overFullScreen
            UIApplication.shared.delegate?.window??.rootViewController?.present(vc, animated: false, completion: nil)
        }
    }
    func securityCompareScreen() {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogCompareSecurityViewController") as? DialogCompareSecurityViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            UIApplication.shared.delegate?.window??.rootViewController?.present(vc, animated: false, completion: nil)
        }
    }
    /*@objc func switchNetwork() {
        let storyboard = UIStoryboard(name: "DrawerNetworkSelection", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DrawerNetworkSelection") as? DrawerNetworkSelectionViewController {
            vc.transitioningDelegate = self
            vc.modalPresentationStyle = .custom
            vc.delegate = self
            //navigationController?.pushViewController(vc, animated: true)
            present(vc, animated: true, completion: nil)
        }
    }*/
}
extension TabViewController: DialogCompareSecurityViewControllerDelegate {
    func onHardwareTap(_ action: CompareSecurityAction) {
        switch action {
        case .setupHardware:
            let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
            if let vc = hwFlow.instantiateViewController(withIdentifier: "WelcomeJadeViewController") as? WelcomeJadeViewController {
                navigationController?.pushViewController(vc, animated: true)
                AnalyticsManager.shared.hwwWallet()
            }
        case .buyJade:
            SafeNavigationManager.shared.navigate( ExternalUrls.buyJadePlus )
        case .none:
            break
        }
    }
}
extension TabViewController: TxDetailsViewControllerDelegate {
    func onMemoEdit() {
        Task { [weak self] in
            await self?.walletTab.reload(discovery: false)
        }
    }
}
/*
extension TabViewController: DrawerNetworkSelectionDelegate {

    // accounts drawer: add new waller
    func didSelectAddWallet() {
        if let vc = AccountNavigator.started() {
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    // accounts drawer: select another account
    func didSelectAccount(account: Account) {
        // don't switch if same account selected
        if account.id == walletModel.wm?.account.id ?? "" {
            return
        } else if let wm = WalletsRepository.shared.get(for: account.id), wm.logged {
            AccountNavigator.navLogged(accountId: account.id)
        } else {
            if let vc = AccountNavigator.login(accountId: account.id) {
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    // accounts drawer: select app settings
    func didSelectSettings() {
        self.presentedViewController?.dismiss(animated: true, completion: {
            let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "WalletSettingsViewController") as? WalletSettingsViewController {
                self.navigationController?.pushViewController(vc, animated: true)
            }
        })
    }

    func didSelectAbout() {
        self.presentedViewController?.dismiss(animated: true, completion: {
            let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "DialogAboutViewController") as? DialogAboutViewController {
                vc.modalPresentationStyle = .overFullScreen
                vc.delegate = self
                self.present(vc, animated: false, completion: nil)
            }
        })
    }
}
extension TabViewController: DialogAboutViewControllerDelegate {
    func openContactUs() {
        presentContactUsViewController(request: ZendeskErrorRequest(shareLogs: true))
    }
}
extension WalletTabBarViewController: DialogGroupListViewControllerDelegate {
    func didSelectIndexPath(_ indexPath: IndexPath, with type: DialogGroupType) {
        switch type {
        case .walletPrefs:
            if let item = WalletPrefs.getSelected(indexPath) {
                switch item {
                case .createAccount:
                    AnalyticsManager.shared.newAccount(account: AccountsRepository.shared.current)
//                    createAccount()
                case .logout:
                    userLogout()
                case .denominations:
                    showDenominationExchange()
                case .rename:
                    rename()
                case .refresh:
//                    tableView.beginRefreshing()
//                    reload(discovery: true)
                    break
                case .archive:
//                    showArchived()
                    break
                case .contact:
                    presentContactUsViewController(request: ZendeskErrorRequest(shareLogs: true))
                }
            }
        }
    }
}
extension TabViewController: UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        if let presented = presented as? DrawerNetworkSelectionViewController {
            return DrawerPresentationController(presentedViewController: presented, presenting: presenting)
        }
        return ModalPresentationController(presentedViewController: presented, presenting: presenting)
    }

    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if presented as? DrawerNetworkSelectionViewController != nil {
            return DrawerAnimator(isPresenting: true)
        } else {
            return ModalAnimator(isPresenting: true)
        }
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if dismissed as? DrawerNetworkSelectionViewController != nil {
            return DrawerAnimator(isPresenting: false)
        } else {
            return ModalAnimator(isPresenting: false)
        }
    }
}
*/
