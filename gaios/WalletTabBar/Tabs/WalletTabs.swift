import UIKit

enum WalletTabs {
    case home
    case transact
    case security
    case setttings

    var tabName: String {
        switch self {
        case .home:
            "Home".localized
        case .transact:
            "Transact".localized
        case .security:
            "Security".localized
        case .setttings:
            "Settings".localized
        }
    }
    var tabIcon: UIImage {
        switch self {
        case .home:
            UIImage(named: "ic_tab_home")!
        case .transact:
            UIImage(named: "ic_tab_transact")!
        case .security:
            UIImage(named: "ic_tab_security")!
        case .setttings:
            UIImage(named: "ic_tab_settings")!
        }
    }
    var tabItem: UITabBarItem {
        UITabBarItem(title: tabName, image: tabIcon, selectedImage: tabIcon)
    }
    static func transactVC(walletViewModel: WalletViewModel) -> TransactViewController {
        // swiftlint:disable force_cast
        let storyboard = UIStoryboard(name: "WalletTabs", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "TransactViewController") as! TransactViewController
        vc.walletViewModel = walletViewModel
        return vc
    }
    static func securityVC() -> SecurityViewController {
        // swiftlint:disable force_cast
        let storyboard = UIStoryboard(name: "WalletTabs", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "SecurityViewController") as! SecurityViewController
        return vc
    }
    static func settingsVC() -> SettingsViewController {
        // swiftlint:disable force_cast
        let storyboard = UIStoryboard(name: "WalletTabs", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "SettingsViewController") as! SettingsViewController
        return vc
    }
    static func homeTab(walletViewModel: WalletViewModel) -> WalletViewController {
        // swiftlint:disable force_cast
        let storyboard = UIStoryboard(name: "Wallet", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "WalletViewController") as! WalletViewController
        vc.viewModel = walletViewModel
        return vc
    }
}
