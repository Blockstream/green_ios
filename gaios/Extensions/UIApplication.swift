import UIKit
extension UIApplication {
    var mainApplicationWindow: UIWindow? {
        let foregroundWindows = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
            .flatMap { $0.windows }

        if let window = foregroundWindows.first(where: { $0.isKeyWindow && $0.windowLevel == .normal })
            ?? foregroundWindows.first(where: { $0.windowLevel == .normal }) {
            return window
        }

        let windows = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }

        return windows.first { $0.isKeyWindow && $0.windowLevel == .normal } ?? windows.first { $0.windowLevel == .normal }
    }

    class var activeKeyWindow: UIWindow? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    class func topViewController(controller: UIViewController? = UIApplication.activeKeyWindow?.rootViewController) -> UIViewController? {
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
