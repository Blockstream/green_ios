import UIKit
extension UIApplication {
    class func topViewController(controller: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }

    static let notificationSettingsURLString: String? = {
        if #available(iOS 16, *) {
            return UIApplication.openNotificationSettingsURLString
        }
        if #available(iOS 15.4, *) {
            return UIApplicationOpenNotificationSettingsURLString
        }
        if #available(iOS 8.0, *) {
            return UIApplication.openSettingsURLString
        }
        return nil
    }()
}
