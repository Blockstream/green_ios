import Foundation
import UIKit
import core

class SafeNavigationManager {

    static let shared = SafeNavigationManager()

    public func navigate(_ urlString: String?) {
        guard let urlString = urlString, let url = URL(string: urlString) else {
            return
        }
        confirm(url)
    }

    public func navigate(_ url: URL) {
        confirm(url)
    }
    
    private func confirm(_ url: URL) {
        guard GdkSettings.read()?.tor ?? false else {
            browse(url)
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
                    self?.browse(url)
                case .cancel:
                    break
                case .copy:
                    UIPasteboard.general.string = url.absoluteString
                    DropAlert().info(message: NSLocalizedString("id_copied_to_clipboard", comment: ""), delay: 1.0)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
            appDelegate?.navigateWindow?.rootViewController = con
        }
        appDelegate?.navigateWindow?.makeKeyAndVisible()
    }
    
    private func browse(_ url: URL) {

        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.navigateWindow = UIWindow(frame: UIScreen.main.bounds)
        appDelegate?.navigateWindow?.windowLevel = .alert
        appDelegate?.navigateWindow?.tag = 999

        if let vc = UIStoryboard(name: "Utility", bundle: .main)
            .instantiateViewController(
                withIdentifier: "BrowserViewController") as? BrowserViewController {
            vc.url = url
            vc.onClose = { () in
                appDelegate?.navigateWindow = nil
            }
            appDelegate?.navigateWindow?.rootViewController = vc
        }
        appDelegate?.navigateWindow?.makeKeyAndVisible()
    }
}
