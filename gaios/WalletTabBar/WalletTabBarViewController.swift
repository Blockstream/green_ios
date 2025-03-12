import UIKit
import core
import gdk

class WalletTabBarViewController: UITabBarController {

    var walletModel: WalletModel!
    private var sIdx: Int = 0
    private var userWillLogout = false
    private var cachedAccount: WalletItem?
    private var notificationObservers: [NSObjectProtocol] = []
    private var isReloading = false

    let tabHomeVC = WalletTab.tabHomeVC()
    let tabTransactVC = WalletTab.tabTransactVC()
    let tabSecurityVC = WalletTab.tabSecurityVC()
    let tabSettingsVC = WalletTab.tabSettingsVC()

    private let drawerItem = ((Bundle.main.loadNibNamed("DrawerBarItem", owner: WalletTabBarViewController.self, options: nil)![0] as? DrawerBarItem)!)

    init(walletModel: WalletModel) {
        self.walletModel = walletModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadNavigationBtns()
        setTabBar()
        Task.detached { [weak self] in
            await self?.walletModel.registerNotifications()
            await self?.reload() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.alpha = 0
        UIView.animate(withDuration: 1.0) {
            self.view.alpha = 1
        }
        drawerIcon(true)

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

//        if URLSchemeManager.shared.isValid {
//            if let bip21 = URLSchemeManager.shared.bip21 {
//                let sendAddressInputViewModel = SendAddressInputViewModel(
//                    input: bip21,
//                    preferredAccount: nil,
//                    txType: .transaction)
//                presentSendAddressInputViewController(sendAddressInputViewModel)
//                URLSchemeManager.shared.url = nil
//            }
//        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        notificationObservers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers = []
        drawerIcon(false)
    }

    func drawerIcon(_ show: Bool) {
        if let bar = navigationController?.navigationBar {
            if show {
                let i = UIImageView(frame: CGRect(x: 0.0, y: bar.frame.height / 2.0 - 5.0, width: 7.0, height: 10.0))
                i.image = UIImage(named: "ic_drawer")
                i.tag = 999
                bar.addSubview(i)
            } else {
                bar.subviews.forEach { if $0.tag == 999 { $0.removeFromSuperview()} }
            }
        }
    }

    func loadNavigationBtns() {
        guard let walletModel else { return }
        drawerItem.configure(img: walletModel.headerIcon, onTap: {[weak self] () in
            self?.switchNetwork()
        })
        let leftItem: UIBarButtonItem = UIBarButtonItem(customView: drawerItem)
        navigationItem.leftBarButtonItem = leftItem

        let desiredWidth = 135.0
        let desiredHeight = 35.0
        let widthConstraint = NSLayoutConstraint(item: drawerItem, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: desiredWidth)
        let heightConstraint = NSLayoutConstraint(item: drawerItem, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: desiredHeight)
        drawerItem.addConstraints([widthConstraint, heightConstraint])

        // setup right menu bar: settings
        let settingsBtn = UIButton(type: .system)
        settingsBtn.contentEdgeInsets = UIEdgeInsets(top: 7.0, left: 7.0, bottom: 7.0, right: 7.0)
        settingsBtn.setImage(UIImage(named: "ic_gear"), for: .normal)
        settingsBtn.addTarget(self, action: #selector(settingsBtnTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: settingsBtn)
    }

    @objc func settingsBtnTapped(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogGroupListViewController") as? DialogGroupListViewController {
            vc.delegate = self
            vc.viewModel = DialogGroupListViewModel(title: "Wallet Preferences".localized, type: .walletPrefs, dataSource: WalletPrefs.getGroupItems())
            vc.modalPresentationStyle = .overFullScreen
            UIApplication.shared.delegate?.window??.rootViewController?.present(vc, animated: false, completion: nil)
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
            Task.detached { [weak self] in await self?.reload() }
        case .Block:
            if walletModel.cachedTransactions.filter({ $0.blockHeight == 0 }).first != nil {
                Task.detached { [weak self] in await self?.reload() }
            }
        case .AssetsUpdated:
            Task.detached { [weak self] in await self?.reload() }
        case .Network:
            if let details = details as? [String: Any],
               let connection = Connection.from(details) as? Connection {
                if connection.connected {
                    Task.detached { [weak self] in await self?.reload() }
                }
            }
        case .Settings, .Ticker, .TwoFactorReset:
            Task.detached { [weak self] in await self?.reload() }
//        case .bip21Scheme:
//            if URLSchemeManager.shared.isValid {
//                if let bip21 = URLSchemeManager.shared.bip21 {
//                    let account = viewModel.accountCellModels[safe: sIdx]
//                    let sendAddressInputViewModel = SendAddressInputViewModel(
//                        input: bip21,
//                        preferredAccount: account?.account,
//                        txType: .transaction)
//                    presentSendAddressInputViewController(sendAddressInputViewModel)
//                    URLSchemeManager.shared.url = nil
//                }
//            }
        default:
            break
        }
    }

    func reload(_ discovery: Bool = false) async {
        if walletModel.paused {
            return
        }
        if isReloading {
            return
        }
        isReloading = true
        try? await self.walletModel.fetchBalances(discovery: discovery)
        self.walletModel.reloadBalances()
        self.updateTabs([.home, .transact])
        _ = try? await self.walletModel.fetchTransactions()
        self.walletModel.reloadTransactions()
        self.updateTabs([.home, .transact])
        //await self?.walletModel.reloadPromoCards()
        try? await Api.shared.fetch()
        isReloading = false
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

    func showContactSupport() {
        let storyboard = UIStoryboard(name: "HelpCenter", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ContactUsViewController") as? ContactUsViewController {
            vc.request = ZendeskErrorRequest(shareLogs: true)
            navigationController?.pushViewController(vc, animated: true)
        }
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
                    try? await BleViewModel.shared.disconnect()
                }
                await WalletManager.current?.disconnect()
                WalletsRepository.shared.delete(for: account?.id ?? "")
                AccountNavigator.goLogout(account: nil)
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

         if selectedIndex == 1 {
             // return false for no action
//             if let nv = parent as? UINavigationController {
//                 nv.navigationBar.topItem?.title = "Transact"
//             }
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
            AccountNavigator.goLogged(account: account)
        } else {
            AccountNavigator.goLogin(account: account)
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
        let storyboard = UIStoryboard(name: "HelpCenter", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ContactUsViewController") as? ContactUsViewController {
            vc.request = ZendeskErrorRequest(shareLogs: true)
            navigationController?.pushViewController(vc, animated: true)
        }
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
                    showContactSupport()
                }
            }
        }
    }
}
extension WalletTabBarViewController: DenominationExchangeViewControllerDelegate {
    func onDenominationExchangeSave() {
        Task.detached { [weak self] in
            //try? await self?.walletModel.loadBalances()
            //try? await self?.walletModel.loadTransactions()
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
            drawerItem.refresh()
        }
    }
    func didCancel() {
    }
}
