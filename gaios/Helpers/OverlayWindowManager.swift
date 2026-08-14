import UIKit

@MainActor
final class OverlayWindowManager {

    static let shared = OverlayWindowManager()

    private var navigateWindow: UIWindow?
    private var resolve2faWindow: UIWindow?

    private init() {}

    func showNavigation(_ viewController: UIViewController) {
        let window = makeWindow()
        window.windowLevel = .alert
        window.tag = 999
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        navigateWindow = window
    }

    func hideNavigation() {
        navigateWindow?.isHidden = true
        navigateWindow?.rootViewController = nil
        navigateWindow = nil
    }

    func showResolve2FA(_ viewController: UIViewController) {
        let window = makeWindow()
        window.windowLevel = .alert
        viewController.view.frame = window.bounds
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        resolve2faWindow = window
    }

    func hideResolve2FA() {
        resolve2faWindow?.isHidden = true
        resolve2faWindow?.rootViewController = nil
        resolve2faWindow = nil
    }

    func hideResolve2FAForBackground() {
        resolve2faWindow?.isHidden = true
    }

    func restoreResolve2FAAfterForeground() {
        guard let window = resolve2faWindow else { return }
        window.isHidden = false
        window.makeKeyAndVisible()
    }

    private func makeWindow() -> UIWindow {
        if let windowScene = UIApplication.shared.mainApplicationWindow?.windowScene ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) {
            return UIWindow(windowScene: windowScene)
        }
        return UIWindow(frame: UIScreen.main.bounds)
    }

}
