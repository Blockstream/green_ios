import UIKit

enum WalletTab: Int, CaseIterable {
    case home = 0
    case transact = 1
    case security = 2
    case settings = 3

    var tabName: String {
        switch self {
        case .home:
            "id_home".localized
        case .transact:
            "id_transact".localized
        case .security:
            "id_security".localized
        case .settings:
            "id_settings".localized
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
}
