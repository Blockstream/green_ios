import UIKit
import core
import gdk

class WalletTabBarViewController: UITabBarController {

    var walletModel: WalletModel!
    private var sIdx: Int = 0
    private var userWillLogout = false
    private var notificationObservers: [NSObjectProtocol] = []
    var isReloading = false
    let wView = WelcomeView()
    let tabHomeVC = WalletTab.tabHomeVC()
    let tabTransactVC = WalletTab.tabTransactVC()
    let tabSecurityVC = WalletTab.tabSecurityVC()
    let tabSettingsVC = WalletTab.tabSettingsVC()

    override func viewDidLoad() {
        super.viewDidLoad()
        setTabBar()
        setupNotifications()
        walletModel.registerNotifications()
        Task.detached { [weak self] in
            // refresh tabs content on load
            await self?.reload(discovery: false, chartUpdate: false) }
    }

    func setupNotifications() {
        EventType.allCases.forEach {
            let observer = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: $0.rawValue),
                                                                  object: nil,
                                                                  queue: .main,
                                                                  using: { [weak self] notification in
                if let eventType = EventType(rawValue: notification.name.rawValue) {
                    self?.handleEvent(eventType, details: notification.userInfo ?? [:])
                }
            })
            notificationObservers.append(observer)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.alpha = 0
        UIView.animate(withDuration: 1.0) {
            self.view.alpha = 1
        }
        navigationController?.isNavigationBarHidden = true
        if walletModel.isFirstLoad, let view = UIApplication.shared.delegate?.window??.rootViewController?.view {
            walletModel.isFirstLoad = false
            // load welcome dialog
            view.addSubview(wView)
            wView.frame = view.frame
            wView.configure(with: WelcomeViewModel(), onTap: {[weak self] in
                self?.wView.removeFromSuperview()
            })
            // load backup alert
            if let wm = walletModel.wm, !wm.account.isHW && !wm.account.isWatchonly {
                BackupHelper.shared.addToBackupList(walletModel.wm?.account.id)
            }
        }
        setSecurityState(BackupHelper.shared.needsBackup(walletId: walletModel.wm?.account.id) ? .alerted : .normal)
        // reload tabs content on appear
        walletModel.reloadBalances()
        walletModel.reloadTransactions()
        updateTabs([.home, .transact])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.isNavigationBarHidden = false
    }

    deinit {
        notificationObservers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers = []
    }

    @objc func settingsBtnTapped(_ sender: Any) {

        let alert = UIAlertController(title: "Settings will be available in the next beta release.", message: "", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "id_ok".localized, style: .default) { _ in })
        DispatchQueue.main.async {
            UIApplication.shared.delegate?.window??.rootViewController?.present(alert, animated: true, completion: nil)
        }

//        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
//        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogGroupListViewController") as? DialogGroupListViewController {
//            vc.delegate = self
//            vc.viewModel = DialogGroupListViewModel(title: "Wallet Preferences".localized, type: .walletPrefs, dataSource: WalletPrefs.getGroupItems())
//            vc.modalPresentationStyle = .overFullScreen
//            UIApplication.shared.delegate?.window??.rootViewController?.present(vc, animated: false, completion: nil)
//        }
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

    func setSecurityState(_ state: SecurityState) {
        walletModel.securityState = state
        switch state {
        case .normal:
            tabSecurityVC.tabBarItem = WalletTab.security.tabItem
        case .alerted:
            let img = WalletTab.security.tabItem.image
            tabSecurityVC.tabBarItem.image = img?.withBadge(iconColor: UIColor.gGrayTxt(), badgeColor: .red)
            tabSecurityVC.tabBarItem.selectedImage = img?.withBadge(iconColor: .white, badgeColor: .red)
        }
    }

    @objc func switchNetwork() {
        let storyboard = UIStoryboard(name: "DrawerNetworkSelection", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DrawerNetworkSelection") as? DrawerNetworkSelectionViewController {
            vc.transitioningDelegate = self
            vc.modalPresentationStyle = .custom
            vc.delegate = self
            present(vc, animated: true, completion: nil)
        }
    }

    func handleEvent(_ eventType: EventType, details: [AnyHashable: Any]) {
        switch eventType {
        case .Transaction, .InvoicePaid, .PaymentFailed, .PaymentSucceed:
            Task.detached { [weak self] in await self?.reload(discovery: false, chartUpdate: false) }
        case .Block:
            if walletModel.existPendingTransaction() {
                Task.detached { [weak self] in await self?.reload(discovery: false, chartUpdate: false) }
            }
        case .AssetsUpdated, .Network, .Settings, .Ticker, .TwoFactorReset:
            walletModel.reloadBalances()
            walletModel.reloadTransactions()
            updateTabs([.home, .transact])
        default:
            break
        }
    }

    func reload(discovery: Bool, chartUpdate: Bool) async {
        if walletModel.paused {
            return
        }
        if isReloading {
            return
        }
        isReloading = true
        try? await self.walletModel.fetchBalances(discovery: discovery)
        walletModel.reloadBalances()
        updateTabs([.home, .transact])
        _ = try? await walletModel.fetchTransactions(reset: true)
        walletModel.reloadTransactions()
        updateTabs([.home, .transact])
        if chartUpdate || Api.shared.currency != walletModel.currency?.lowercased() {
            try? await refreshChart()
        }
        await walletModel.reloadPromoCards()
        walletModel.reloadBackupCards()

        isReloading = false
        self.updateTabs([.home, .transact])
    }

    func refreshChart() async throws {
        try? await Api.shared.fetch(currency: (walletModel.currency ?? "USD").lowercased())
        if Api.shared.priceCache == nil {
            try? await Api.shared.fetch(currency: "USD".lowercased())
        }
    }

    @MainActor
    func updateTabs(_ tabs: [WalletTab]) {
        tabs.forEach {
            updateTab($0)
        }
    }

    @MainActor
    func updateTab(_ tab: WalletTab) {
        switch tab {
        case .home:
            tabHomeVC.tableView?.reloadData()
        case .transact:
            tabTransactVC.tableView?.reloadData()
        case .security:
            break
        case .settings:
            break
        }
    }

    @MainActor
    func onHide(_ value: Bool) {
        walletModel.hideBalance = value
        updateTabs([.home, .transact])
    }

    func userLogout() {
        // userWillLogout = true
//        self.presentedViewController?.dismiss(animated: true, completion: {
            if AppSettings.shared.gdkSettings?.tor ?? false {
                self.startLoader(message: "id_logout".localized)
            }
            Task {
                let account = self.walletModel.wm?.account
                if account?.isHW ?? false {
                    try? await BleHwManager.shared.disconnect()
                }
                await WalletManager.current?.disconnect()
                WalletsRepository.shared.delete(for: account?.id ?? "")
                AccountNavigator.goLogout(accountId: nil)
                self.stopLoader()
            }
//        })
    }

    func showDenominationExchange() {
        AnalyticsManager.shared.preferredUnits(account: AccountsRepository.shared.current)

        let ltFlow = UIStoryboard(name: "DenominationExchangeFlow", bundle: nil)
        if let vc = ltFlow.instantiateViewController(withIdentifier: "DenominationExchangeViewController") as? DenominationExchangeViewController {
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            UIApplication.shared.delegate?.window??.rootViewController?.present(vc, animated: false, completion: nil)
        }
    }

    func rename() {
        let account = AccountsRepository.shared.current
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogRenameViewController") as? DialogRenameViewController {
            vc.delegate = self
            vc.index = nil
            vc.prefill = account?.name ?? ""
            vc.modalPresentationStyle = .overFullScreen
            UIApplication.shared.delegate?.window??.rootViewController?.present(vc, animated: false, completion: nil)
        }
    }
}

extension WalletTabBarViewController: UITabBarControllerDelegate {

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {

         guard let selectedIndex = tabBarController.viewControllers?.firstIndex(of: viewController) else {
            return true
         }

         if selectedIndex == 3 {
             // return false for no action
//             if let nv = parent as? UINavigationController {
//                 nv.navigationBar.topItem?.title = "Transact"
//             }
             settingsBtnTapped(self)
             return false
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
        AccountNavigator.goAddWallet(nv: navigationController)
    }

    // accounts drawer: select another account
    func didSelectAccount(account: Account) {
        // don't switch if same account selected
        if account.id == walletModel.wm?.account.id ?? "" {
            return
        } else if let wm = WalletsRepository.shared.get(for: account.id), wm.logged {
            AccountNavigator.goLogged(accountId: account.id)
        } else {
            AccountNavigator.goLogin(accountId: account.id)
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
extension WalletTabBarViewController: DialogAboutViewControllerDelegate {
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
extension WalletTabBarViewController: DenominationExchangeViewControllerDelegate {
    func onDenominationExchangeSave() {
        Task.detached { [weak self] in
            // try? await self?.walletModel.loadBalances()
            // try? await self?.walletModel.loadTransactions()
            await self?.updateTabs([.home, .transact])
        }
    }
}
extension WalletTabBarViewController: DialogRenameViewControllerDelegate {

    func didRename(name: String, index: String?) {
        if var account = AccountsRepository.shared.current {
            account.name = name
            WalletManager.current?.account = account
            // AccountsRepository.shared.upsert(account)
            AnalyticsManager.shared.renameWallet()
            Task.detached { [weak self] in
                // try? await self?.walletModel.loadBalances()
                // try? await self?.walletModel.loadTransactions()
                await self?.updateTabs([.home, .transact, .security, .settings])
            }
        }
    }
    func didCancel() {
    }
}
