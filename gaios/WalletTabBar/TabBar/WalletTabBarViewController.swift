import UIKit
import core
import gdk
import AsyncAlgorithms

class WalletTabBarViewController: UITabBarController {

    private let walletTabBarModel: WalletTabBarModel
    private let tabHomeVC: TabHomeVC
    private let tabTransactVC: TabTransactVC
    private let tabSecurityVC: TabSecurityVC
    private let tabSettingsVC: TabSettingsVC
    private let wView = WelcomeView()

    var walletDataModel: WalletDataModel { walletTabBarModel.walletDataModel }
    var wallet: WalletManager { walletTabBarModel.wallet }
    var mainAccount: Account { walletTabBarModel.mainAccount }

    init?(coder: NSCoder, walletTabBarModel: WalletTabBarModel) {
        self.walletTabBarModel = walletTabBarModel
        self.tabHomeVC = walletTabBarModel.tabHomeVC()
        self.tabTransactVC = walletTabBarModel.tabTransactVC()
        self.tabSecurityVC = walletTabBarModel.tabSecurityVC()
        self.tabSettingsVC = walletTabBarModel.tabSettingsVC()

        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("You must create this view controller with a view model.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setTabBar()
        AppNotifications.shared.checkNotificationStatusAndPromptIfNeeded(from: self)
        
        Task.detached { [weak self] in
            await self?.setupRemoteNotifications()
        }
        Task.detached { [weak self] in
            await self?.walletTabBarModel.completePendingSwaps()
        }
        Task.detached { [weak self] in
            await self?.walletTabBarModel.callAnalytics()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task.detached { [weak self] in
            try await self?.walletTabBarModel.wallet.refreshRegistryIfNeeded()
        }
    }

    func setupRemoteNotifications() async {
        let res = Task.detached(priority: .background) { [weak self] in
            try await self?.walletTabBarModel.registerNotifications()
        }
        switch try? await res.value {
        case .none:
            DropAlert().error(message: "Notifications error".localized)
        default:
            break
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
        if walletTabBarModel.isFirstLoad {
            // moved this reset in model
            // after discovery completes
            // walletModel.isFirstLoad = false
            // load welcome dialog
            addWelcomeDialog()
            // load backup alert
            if !walletTabBarModel.wallet.isHW && !walletTabBarModel.wallet.isWatchonly {
                BackupHelper.shared.addToBackupList(mainAccount.id)
            }
        }
        setSecurityState(BackupHelper.shared.needsBackup(walletId: mainAccount.id) ? .alerted : .normal)
    }

    func addWelcomeDialog() {
        // load welcome dialog
        if let view = UIApplication.shared.delegate?.window??.rootViewController?.view {
            view.addSubview(wView)
        }
        wView.frame = view.frame
        wView.configure(with: WelcomeViewModel(), onTap: {[weak self] in
            AnalyticsManager.shared.swwCreated(account: self?.mainAccount)
            self?.wView.removeFromSuperview()
        })
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.isNavigationBarHidden = false
    }

    @objc func switchNetwork() {
        let storyboard = UIStoryboard(name: "DrawerNetworkSelection", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DrawerNetworkSelection") as? DrawerNetworkSelectionViewController {
            vc.transitioningDelegate = self
            vc.modalPresentationStyle = .custom
            vc.delegate = self
            // navigationController?.pushViewController(vc, animated: true)
            present(vc, animated: true, completion: nil)
        }
    }

    func setTabBar() {
        let tabBar = { () -> WalletTabBar in
                let tabBar = WalletTabBar()
                tabBar.delegate = self
                return tabBar
            }()
        self.setValue(tabBar, forKey: "tabBar")
        tabBar.isTranslucent = true
        tabBar.tintColor = .white
        tabBar.unselectedItemTintColor = UIColor.gGrayTxt()
        tabBar.backgroundColor = UIColor.gGrayTabBar()
        // tabBar.delegate = self
        tabHomeVC.tabBarItem = WalletTab.home.tabItem
        tabTransactVC.tabBarItem = WalletTab.transact.tabItem
        tabSecurityVC.tabBarItem = WalletTab.security.tabItem
        tabSettingsVC.tabBarItem = WalletTab.settings.tabItem
        let viewControllers = [tabHomeVC, tabTransactVC, tabSecurityVC, tabSettingsVC]
        self.setViewControllers(viewControllers, animated: false)
        delegate = self
    }
    func changeTab(_ tab: WalletTab) {
        self.selectedIndex = tab.rawValue
    }
    func setSecurityState(_ state: SecurityState) {
        walletTabBarModel.securityState = state
        switch state {
        case .normal:
            tabSecurityVC.tabBarItem = WalletTab.security.tabItem
        case .alerted:
            let img = WalletTab.security.tabItem.image
            tabSecurityVC.tabBarItem.image = img?.withBadge(iconColor: UIColor.gGrayTxt(), badgeColor: .red)
            tabSecurityVC.tabBarItem.selectedImage = img?.withBadge(iconColor: .white, badgeColor: .red)
        }
    }

    func userLogout() {
        self.startLoader(message: "id_logging_out".localized)
        Task {
            if mainAccount.isHW {
                try? await BleHwManager.shared.disconnect()
            }
            await wallet.disconnect()
            WalletsRepository.shared.delete(for: mainAccount.id)
            AccountNavigator.navLogout(accountId: mainAccount.id)
            self.stopLoader()
        }
    }
}

extension WalletTabBarViewController: UITabBarControllerDelegate {

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        guard let selectedIndex = tabBarController.viewControllers?.firstIndex(of: viewController) else {
            return true
        }
        guard let fromView = selectedViewController?.view, let toView = viewController.view else {
            return false
        }
        if fromView != toView {
            UIView.transition(from: fromView, to: toView, duration: 0.4, options: [.transitionCrossDissolve], completion: nil)
        }
        return true
    }
}

extension WalletTabBarViewController: UIViewControllerTransitioningDelegate {
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

extension WalletTabBarViewController: DrawerNetworkSelectionDelegate {

    // accounts drawer: add new waller
    func didSelectAddWallet() {
        if let vc = AccountNavigator.started() {
            self.navigationController?.pushViewController(viewController: vc, animated: true) {
                self.presentedViewController?.dismiss(animated: true)
            }
        }
    }

    // accounts drawer: select another account
    func didSelectAccount(account: Account) {
        // don't switch if same account selected
        if account.id == AccountsRepository.shared.current?.id ?? "" {
            presentedViewController?.dismiss(animated: true)
        } else if let wm = WalletsRepository.shared.get(for: account.id), wm.logged {
            AccountsRepository.shared.current = account
            AccountNavigator.navLogged(accountId: account.id)
        } else {
            AccountsRepository.shared.current = account
            AccountNavigator.navLogin(accountId: account.id)
        }
    }

    // accounts drawer: select app settings
    func didSelectSettings() {
        let storyboard = UIStoryboard(name: "AppSettings", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AppSettingsViewController") as? AppSettingsViewController {
            self.navigationController?.pushViewController(viewController: vc, animated: false) {
            }
        }
        self.presentedViewController?.dismiss(animated: true)
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

extension WalletTabBarViewController: DialogAboutViewControllerDelegate {
    func openContactUs() {
        presentContactUsViewController(request: ZendeskErrorRequest(shareLogs: true))
    }
}
