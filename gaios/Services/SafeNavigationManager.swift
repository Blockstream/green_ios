import Foundation
import UIKit
import core

class SafeNavigationManager {

    static let shared = SafeNavigationManager()

    public func navigate(_ urlString: String?, exitApp: Bool = false, title: String? = nil, completion: (()->())? = nil) {
        guard let urlString = urlString, let url = URL(string: urlString) else {
            return
        }
        confirm(url, exitApp: exitApp, title: title, completion: completion)
    }

    public func navigate(_ url: URL, exitApp: Bool = false) {
        confirm(url, exitApp: exitApp)
    }

    private func confirm(_ url: URL, exitApp: Bool, title: String? = nil, completion: (()->())? = nil) {
        guard GdkSettings.read()?.tor ?? false else {
            browse(url, exitApp: exitApp, title: title, completion: completion)
            return
        }

        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.navigateWindow = UIWindow(frame: UIScreen.main.bounds)
        appDelegate?.navigateWindow?.windowLevel = .alert
        appDelegate?.navigateWindow?.tag = 999

        if let con = UIStoryboard(name: "Shared", bundle: .main)
            .instantiateViewController(
                withIdentifier: "DialogSafeNavigationViewController") as? DialogSafeNavigationViewController {
            con.onSelect = { [weak self] (action: SafeNavigationAction) in

                appDelegate?.navigateWindow = nil

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
            appDelegate?.navigateWindow?.rootViewController = con
        }
        appDelegate?.navigateWindow?.makeKeyAndVisible()
    }

    private func browse(_ url: URL, exitApp: Bool, title: String? = nil, completion: (()->())? = nil) {

        if exitApp == true {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        } else {
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            appDelegate?.navigateWindow = UIWindow(frame: UIScreen.main.bounds)
            appDelegate?.navigateWindow?.windowLevel = .alert
            appDelegate?.navigateWindow?.tag = 999

            if let vc = UIStoryboard(name: "Utility", bundle: .main)
                .instantiateViewController(
                    withIdentifier: "BrowserViewController") as? BrowserViewController {
                vc.url = url
                vc.titleStr = title
                vc.onClose = { () in
                    appDelegate?.navigateWindow = nil
                    completion?()
                }
                appDelegate?.navigateWindow?.rootViewController = vc
            }
            appDelegate?.navigateWindow?.makeKeyAndVisible()
        }
    }
}
