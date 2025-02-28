import UIKit
import core

class WalletTabBarViewController: UITabBarController {

    var walletViewModel: WalletViewModel!

    private let drawerItem = ((Bundle.main.loadNibNamed("DrawerBarItem", owner: WalletTabBarViewController.self, options: nil)![0] as? DrawerBarItem)!)

    init(walletViewModel: WalletViewModel!) {
        self.walletViewModel = walletViewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.alpha = 0
        UIView.animate(withDuration: 0.7) {
            self.view.alpha = 1
        }
        setDrawer()
        setTabBar()
    }

    func setDrawer() {
        drawerItem.configure(img: walletViewModel.headerIcon, onTap: {[weak self] () in
            self?.switchNetwork()
        })
        let leftItem: UIBarButtonItem = UIBarButtonItem(customView: drawerItem)
        navigationItem.leftBarButtonItem = leftItem

        let desiredWidth = 135.0
        let desiredHeight = 35.0
        let widthConstraint = NSLayoutConstraint(item: drawerItem, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: desiredWidth)
        let heightConstraint = NSLayoutConstraint(item: drawerItem, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: desiredHeight)
        drawerItem.addConstraints([widthConstraint, heightConstraint])
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
        tabBar.unselectedItemTintColor = UIColor.gW60()
        tabBar.backgroundColor = UIColor.gGrayElement()
        // tabBar.delegate = self
        let homeVC = WalletTabs.homeTab(walletViewModel: walletViewModel)
        let transactVC = WalletTabs.transactVC(walletViewModel: walletViewModel)
        let securityVC = WalletTabs.securityVC()
        let settingsVC = WalletTabs.settingsVC()

        homeVC.tabBarItem = WalletTabs.home.tabItem
        transactVC.tabBarItem = WalletTabs.transact.tabItem
        securityVC.tabBarItem = WalletTabs.security.tabItem
        settingsVC.tabBarItem = WalletTabs.setttings.tabItem

        let viewControllers = [homeVC, transactVC, securityVC, settingsVC]
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
        if account.id == walletViewModel.wm?.account.id ?? "" {
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
//        self.presentedViewController?.dismiss(animated: true, completion: {
//            let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
//            if let vc = storyboard.instantiateViewController(withIdentifier: "DialogAboutViewController") as? DialogAboutViewController {
//                vc.modalPresentationStyle = .overFullScreen
//                vc.delegate = self
//                self.present(vc, animated: false, completion: nil)
//            }
//        })
    }
}
