import Foundation
import gdk
import UIKit
import AsyncBluetooth
import core

class AccountNavigator {

    @MainActor
    // open the account if just logged or redirect to login
    static func goLogin(accountId: String) {
        let account = AccountsRepository.shared.get(for: accountId)!
        let nv = UINavigationController()
        let vcHome: HomeViewController? = instantiateViewController(storyboard: "Home", identifier: "Home")
        let vcLogin: LoginViewController? = instantiateViewController(storyboard: "Home", identifier: "LoginViewController")
        let vcConnect: ConnectViewController? = instantiateViewController(storyboard: "HWFlow", identifier: "ConnectViewController")
        let vcWatch: WOLoginViewController? = instantiateViewController(storyboard: "WOFlow", identifier: "WOLoginViewController")
        if account.isDerivedLightning {
            vcLogin?.viewModel = LoginViewModel(account: account)
            nv.setViewControllers([vcHome!, vcLogin!], animated: true)
        } else if account.isWatchonly {
            vcWatch?.account = account
            nv.setViewControllers([vcHome!, vcWatch!], animated: true)
        } else if account.isHW {
            vcConnect?.viewModel = ConnectViewModel(
                account: account,
                firstConnection: false)
            nv.setViewControllers([vcHome!, vcConnect!], animated: true)
        } else {
            vcLogin?.viewModel = LoginViewModel(account: account)
            nv.setViewControllers([vcHome!, vcLogin!], animated: true)
        }
        changeRoot(root: nv, animated: true)
    }

    @MainActor
    static func goLogged(accountId: String, isFirstLoad: Bool = false) {
        let account = AccountsRepository.shared.get(for: accountId)!
        AccountsRepository.shared.current = account
        let walletModel = WalletModel()
        if let vc: ContainerViewController = instantiateViewController(storyboard: "Wallet", identifier: "Container") {
            vc.walletModel = walletModel
            vc.walletModel?.isFirstLoad = isFirstLoad
            changeRoot(root: vc)
        }
    }

    @MainActor
    static func goLogout(accountId: String?) {
        if let accountId = accountId {
            goLogin(accountId: accountId)
        } else {
            goHome()
        }
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.resolve2faOff()
            appDelegate.window?.endEditing(true)
        }
    }

    @MainActor
    static func goHome() {
        let nv = UINavigationController()
        let home: HomeViewController? = instantiateViewController(storyboard: "Home", identifier: "Home")
        nv.setViewControllers([home!], animated: true)
        changeRoot(root: nv)
    }

    @MainActor
    static func goFirstPage() {
        let nv = UINavigationController()
        if AccountsRepository.shared.accounts.isEmpty {
            let onboard: GetStartedOnBoardViewController? = instantiateViewController(storyboard: "OnBoard", identifier: "GetStartedOnBoardViewController")
            nv.setViewControllers([onboard!], animated: true)
        } else {
            let list = AccountsRepository.shared.accounts.filter { $0.hidden == false}
            if list.count == 1, let account = list.first, account.getDerivedLightningAccount() == nil {
                goLogin(accountId: account.id)
                return
            } else {
                let home: HomeViewController? = instantiateViewController(storyboard: "Home", identifier: "Home")
                nv.setViewControllers([home!], animated: true)
            }
        }
        changeRoot(root: nv)
    }

    static func goAddWallet(nv: UINavigationController?) {
        let nv = UINavigationController()
        let home: HomeViewController? = instantiateViewController(storyboard: "Home", identifier: "Home")
        let onboard: GetStartedOnBoardViewController? = instantiateViewController(storyboard: "OnBoard", identifier: "GetStartedOnBoardViewController")
        nv.setViewControllers([home!, onboard!], animated: true)
        changeRoot(root: nv)
    }

    static func instantiateViewController<K>(storyboard: String, identifier: String) -> K? {
        let storyboard = UIStoryboard(name: storyboard, bundle: nil)
        return storyboard.instantiateViewController(withIdentifier: identifier) as? K
    }

    static func changeRoot(root: UIViewController, animated: Bool = true) {
        let appDelegate = UIApplication.shared.delegate
        if appDelegate?.window??.rootViewController == nil {
            appDelegate?.window??.rootViewController = root
            return
        }
        if animated {
            ScreenLockWindow.shared.suspend()
            UIView.animate(withDuration: 0.2, delay: 0.0, options: UIView.AnimationOptions.curveEaseOut, animations: {
                appDelegate?.window??.rootViewController?.view.alpha = 0.0
            }, completion: { (_) -> Void  in
                UIApplication.shared.windows.forEach { window in
                    window.subviews.forEach { view in
                        if let loader = view.viewWithTag(Loader.tag) as? Loader {
                            loader.stop()
                            loader.removeFromSuperview()
                        }
                    }
                }
                appDelegate?.window??.rootViewController = root
                appDelegate?.window??.rootViewController?.view.alpha = 0.0
                UIView.animate(withDuration: 0.2, delay: 0.0, options: UIView.AnimationOptions.curveEaseIn, animations: {
                    appDelegate?.window??.rootViewController?.view.alpha = 1.0
                }, completion: {_ in
                    ScreenLockWindow.shared.resume()
                })
            })
        } else {
            appDelegate?.window??.rootViewController = root
        }
    }
}
