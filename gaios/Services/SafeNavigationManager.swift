import Foundation
import UIKit
import core

class SafeNavigationManager {

    static let shared = SafeNavigationManager()

    public func navigate(_ urlString: String?, exitApp: Bool = false, title: String? = nil, completion: (() -> Void)? = nil) {
        guard let urlString = urlString, let url = URL(string: urlString) else {
            return
        }
        confirm(url, exitApp: exitApp, title: title, completion: completion)
    }

    public func navigate(_ url: URL, exitApp: Bool = false) {
        confirm(url, exitApp: exitApp)
    }

    private func confirm(_ url: URL, exitApp: Bool, title: String? = nil, completion: (() -> Void)? = nil) {
        guard GdkSettings.read()?.tor ?? false else {
            browse(url, exitApp: exitApp, title: title, completion: completion)
            return
        }

        if let con = UIStoryboard(name: "Shared", bundle: .main)
            .instantiateViewController(
                withIdentifier: "DialogSafeNavigationViewController") as? DialogSafeNavigationViewController {
            con.onSelect = { [weak self] (action: SafeNavigationAction) in

                Task { @MainActor in
                    OverlayWindowManager.shared.hideNavigation()
                }

                switch action {
                case .authorize:
                    self?.browse(url, exitApp: exitApp, title: title, completion: completion)
                case .cancel:
                    break
                case .copy:
                    UIPasteboard.general.string = url.absoluteString
                    DropAlert().info(message: "id_copied_to_clipboard".localized, delay: 1.0)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
            Task { @MainActor in
                OverlayWindowManager.shared.showNavigation(con)
            }
        }
    }

    private func browse(_ url: URL, exitApp: Bool, title: String? = nil, completion: (() -> Void)? = nil) {

        if exitApp == true {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        } else {
            if let vc = UIStoryboard(name: "Utility", bundle: .main)
                .instantiateViewController(
                    withIdentifier: "BrowserViewController") as? BrowserViewController {
                vc.url = url
                vc.titleStr = title
                vc.onClose = { () in
                    Task { @MainActor in
                        OverlayWindowManager.shared.hideNavigation()
                    }
                    completion?()
                }
                Task { @MainActor in
                    OverlayWindowManager.shared.showNavigation(vc)
                }
            }
        }
    }
}
