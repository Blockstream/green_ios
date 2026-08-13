import UIKit

final class OverlayWindowManager {

    static let shared = OverlayWindowManager()

    private var navigateWindow: UIWindow?
    private var resolve2faWindow: UIWindow?

    private init() {}

    func showNavigation(_ viewController: UIViewController) {
        runOnMain { [weak self] in
            guard let self else { return }
            let window = self.makeWindow()
            window.windowLevel = .alert
            window.tag = 999
            window.rootViewController = viewController
            window.makeKeyAndVisible()
            self.navigateWindow = window
        }
    }

    func hideNavigation() {
        runOnMain { [weak self] in
            self?.navigateWindow?.isHidden = true
            self?.navigateWindow?.rootViewController = nil
            self?.navigateWindow = nil
        }
    }

    func showResolve2FA(_ viewController: UIViewController) {
        runOnMain { [weak self] in
            guard let self else { return }
            let window = self.makeWindow()
            window.windowLevel = .alert
            viewController.view.frame = window.bounds
            window.rootViewController = viewController
            window.makeKeyAndVisible()
            self.resolve2faWindow = window
        }
    }

    func hideResolve2FA() {
        runOnMain { [weak self] in
            self?.resolve2faWindow?.isHidden = true
            self?.resolve2faWindow?.rootViewController = nil
            self?.resolve2faWindow = nil
        }
    }

    func hideResolve2FAForBackground() {
        runOnMain { [weak self] in
            self?.resolve2faWindow?.isHidden = true
        }
    }

    func restoreResolve2FAAfterForeground() {
        runOnMain { [weak self] in
            guard let window = self?.resolve2faWindow else { return }
            window.isHidden = false
            window.makeKeyAndVisible()
        }
    }

    private func makeWindow() -> UIWindow {
        if let windowScene = UIApplication.shared.mainApplicationWindow?.windowScene ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) {
            return UIWindow(windowScene: windowScene)
        }
        return UIWindow(frame: UIScreen.main.bounds)
    }

    private func runOnMain(_ action: @escaping () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async(execute: action)
        }
    }
}
