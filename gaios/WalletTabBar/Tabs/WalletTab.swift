import UIKit

enum WalletTab: Int, CaseIterable {
    case home = 0
    case transact = 1
    case security = 2
    case settings = 3

    var tabName: String {
        switch self {
        case .home:
            "Home".localized
        case .transact:
            "Transact".localized
        case .security:
            "Security".localized
        case .settings:
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
        case .settings:
            UIImage(named: "ic_tab_settings")!
        }
    }
    var tabItem: UITabBarItem {
        UITabBarItem(title: tabName, image: tabIcon, selectedImage: tabIcon)
    }
    static func tabTransactVC() -> TabTransactVC {
        // swiftlint:disable force_cast
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "TabTransactVC") as! TabTransactVC
        return vc
    }
    static func tabSecurityVC() -> TabSecurityVC {
        // swiftlint:disable force_cast
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "TabSecurityVC") as! TabSecurityVC
        return vc
    }
    static func tabSettingsVC() -> TabSettingsVC {
        // swiftlint:disable force_cast
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "TabSettingsVC") as! TabSettingsVC
        return vc
    }
    static func tabHomeVC() -> TabHomeVC {
        // swiftlint:disable force_cast
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "TabHomeVC") as! TabHomeVC
        return vc
    }
}
