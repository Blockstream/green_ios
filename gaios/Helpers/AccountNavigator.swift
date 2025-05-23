import Foundation
import gdk
import UIKit
import AsyncBluetooth
import core

class AccountNavigator {

    static func home() -> HomeViewController? {
         instantiateViewController(storyboard: "Home", identifier: "Home")
    }
    static func navV5() {
        let nv = UINavigationController()
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "V5ViewController") as? V5ViewController {
            nv.setViewControllers([vc], animated: true)
            changeRoot(root: nv)
        }
    }
    static func navHome() {
        let nv = UINavigationController()
        if let vc = home() {
            nv.setViewControllers([vc], animated: true)
            changeRoot(root: nv)
        }
    }

    @MainActor
    static func login(accountId: String, autologin: Bool) -> UIViewController? {
        let account = AccountsRepository.shared.get(for: accountId)!
        let vcLogin: LoginViewController? = instantiateViewController(storyboard: "Home", identifier: "LoginViewController")
        let vcBiometricLogin: BiometricLoginViewController? = instantiateViewController(storyboard: "Home", identifier: "BiometricLoginViewController")
        let vcConnect: ConnectViewController? = instantiateViewController(storyboard: "HWFlow", identifier: "ConnectViewController")
        let vcWatch: WOLoginViewController? = instantiateViewController(storyboard: "WOFlow", identifier: "WOLoginViewController")
        if account.isHW {
            vcConnect?.viewModel = ConnectViewModel(
                account: account,
                firstConnection: false,
                storeConnection: true,
                autologin: autologin)
            return vcConnect
        } else if account.isWatchonly {
            vcWatch?.account = account
            return vcWatch
        } else if account.hasBioPin || account.hasWoCredentials {
            vcBiometricLogin?.viewModel = LoginViewModel(account: account, autologin: autologin)
            return vcBiometricLogin
        } else {
            vcLogin?.viewModel = LoginViewModel(account: account, autologin: autologin)
            return vcLogin
        }
    }

    @MainActor
    static func logged(accountId: String, isFirstLoad: Bool = false) -> UIViewController? {
        let account = AccountsRepository.shared.get(for: accountId)!
        AccountsRepository.shared.current = account
        let walletModel = WalletModel()
        let vc: WalletTabBarViewController? = instantiateViewController(storyboard: "WalletTab", identifier: "WalletTabBarViewController")
        vc?.walletModel = walletModel
        vc?.walletModel?.isFirstLoad = isFirstLoad
        return vc
    }

    @MainActor
    static func started() -> GetStartedOnBoardViewController? {
        instantiateViewController(storyboard: "OnBoard", identifier: "GetStartedOnBoardViewController")
    }

    @MainActor
    static func setup() -> SetupNewViewController? {
        instantiateViewController(storyboard: "OnBoard", identifier: "SetupNewViewController")
    }
    @MainActor
    static func recover() -> RecoveryCreateViewController? {
        instantiateViewController(storyboard: "Recovery", identifier: "RecoveryCreateViewController")
    }
    @MainActor
    static func mnemonic() -> ShowMnemonicsViewController? {
        instantiateViewController(storyboard: "UserSettings", identifier: "ShowMnemonicsViewController")
    }

    @MainActor
    static func navLogged(accountId: String, isFirstLoad: Bool = false) {
        if let vc = logged(accountId: accountId, isFirstLoad: isFirstLoad) {
            let nv = UINavigationController()
            nv.setViewControllers([vc], animated: true)
            changeRoot(root: nv)
        }
    }

    @MainActor
    static func navStarted() {
        if let vc = started() {
            let nv = UINavigationController()
            nv.setViewControllers([vc], animated: true)
            changeRoot(root: nv)
        }
    }

    @MainActor
    static func navLogin(accountId: String, autologin: Bool = true) {
        if let vcHome = home(),
        let vcLogin = login(accountId: accountId, autologin: autologin) {
            let nv = UINavigationController()
            nv.setViewControllers([vcHome, vcLogin], animated: true)
            changeRoot(root: nv)
        }
    }

    @MainActor
    static func navLogout(accountId: String?) {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.resolve2faOff()
            appDelegate.window?.endEditing(true)
        }
        let wallets = AccountsRepository.shared.accounts.filter { $0.hidden == false}
        if wallets.isEmpty {
            // if there are no wallets
            navStarted()
        } else if wallets.count == 1, let accountId = accountId {
            navLogin(accountId: accountId, autologin: false)
        } else {
            navHome()
        }
    }

    @MainActor
    static func navFirstPage() {
        let wallets = AccountsRepository.shared.accounts.filter { $0.hidden == false}
        if wallets.isEmpty {
            // if there are no wallets
            UserDefaults.standard.set(true, forKey: AppStorageConstants.v5Treiggered.rawValue)
            navStarted()
        } else if wallets.count == 1, let walletId = wallets.first?.id {
            if UserDefaults.standard.bool(forKey: AppStorageConstants.v5Treiggered.rawValue) != true {
                navV5()
            } else {
                navLogin(accountId: walletId)
            }
        } else {
            if UserDefaults.standard.bool(forKey: AppStorageConstants.v5Treiggered.rawValue) != true {
                navV5()
            } else {
                navHome()
            }
        }
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
