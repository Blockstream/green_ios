import UIKit
import core

import AsyncAlgorithms

class WalletTabBarViewController: UITabBarController {

    private let walletTabBarModel: WalletTabBarModel
    private let tabHomeVC: TabHomeVC
    private let tabTransactVC: TabTransactVC
    private let tabSecurityVC: TabSecurityVC
    private let tabSettingsVC: TabSettingsVC
    private let wView = WelcomeView()

    var walletDataModel: WalletDataModel { walletTabBarModel.walletDataModel }
    var wm: WalletManager { walletTabBarModel.wm }
    var mainWallet: Wallet { walletTabBarModel.mainWallet }

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
        walletTabBarModel.startup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if walletTabBarModel.showWelcomeStatus() {
            addWelcomeDialog()
        }
    }

    func addWelcomeDialog() {
        // load welcome dialog
        guard let windowView = view.window else {
            return
        }
        wView.frame = windowView.bounds
        windowView.addSubview(wView)
        wView.configure(with: WelcomeViewModel(), onTap: {[weak self] in
            AnalyticsManager.shared.swwCreated(wallet: self?.mainWallet)
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
        
        var needsBackup = BackupHelper.shared.needsBackup(walletId: mainWallet.id)
        if walletTabBarModel.isCreated && !wm.isHW && !wm.isWatchonly {
            needsBackup = true
        }
        setSecurityState(needsBackup ? .alerted : .normal)
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
            if mainWallet.isHW {
                try? await BleHwManager.shared.disconnect()
            }
            await wm.disconnect()
            if wm.isEphemeral {
                await WalletsStorage.shared.remove(mainWallet)
            }
            WalletsRepository.shared.delete(for: mainWallet.id)
            WalletNavigator.navLogout(walletId: wm.isEphemeral ? nil : mainWallet.id)
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
        if let vc = WalletNavigator.started() {
            self.navigationController?.pushViewController(viewController: vc, animated: true) {
                self.presentedViewController?.dismiss(animated: true)
            }
        }
    }

    // accounts drawer: select another account
    func didSelectWallet(wallet: Wallet) {
        // don't switch if same account selected
        if wallet.id == WalletsStorage.shared.current?.id ?? "" {
            presentedViewController?.dismiss(animated: true)
        } else if let wm = WalletsRepository.shared.get(for: wallet.id), wm.logged {
            WalletsStorage.shared.current = wallet
            WalletNavigator.navLogged(walletId: wallet.id)
        } else {
            WalletsStorage.shared.current = wallet
            WalletNavigator.navLogin(walletId: wallet.id)
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
