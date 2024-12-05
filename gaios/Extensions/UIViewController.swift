import Foundation
import UIKit
import core
import gdk
import greenaddress
import BreezSDK
import hw

enum UIAlertOption: String {
    case `continue` = "id_continue"
    case `cancel` = "id_cancel"
}

extension UIViewController {

    @MainActor
    func showAlert(title: String, message: String, completion: @escaping () -> () = { }) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message.localized, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: NSLocalizedString("id_continue", comment: ""), style: .cancel) { _ in completion() })
            self.present(alert, animated: true, completion: nil)
        }
    }

    @MainActor
    func showError(_ message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: NSLocalizedString("id_error", comment: ""), message: message.localized, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("id_continue", comment: ""), style: .cancel) { _ in })
            self.present(alert, animated: true, completion: nil)
        }
    }
    @MainActor
    func showError(_ err: Error) {
        guard let msg = err.description() else {
            return
        }
        DispatchQueue.main.async {
            let alert = UIAlertController(title: NSLocalizedString("id_error", comment: ""), message: msg.localized, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("id_continue", comment: ""), style: .cancel) { _ in })
            self.present(alert, animated: true, completion: nil)
        }
    }

    @MainActor
    func showOpenSupportUrl(_ request: DialogErrorRequest) {
        Task {
            let url = await ZendeskSdk.shared.createNewTicketUrl(
                subject: request.subject,
                email: nil,
                message: nil,
                error: request.msg,
                network: request.network,
                hw: request.hw)
            if let url = url {
                SafeNavigationManager.shared.navigate(url)
            }
        }
    }

    @MainActor
    func showReportError(account: Account?, wallet: WalletItem?, prettyError: String, screenName: String, paymentHash: String? = nil) {
        let request = DialogErrorRequest(
            account: account,
            networkType: wallet?.networkType ?? .bitcoinSS,
            error: prettyError,
            screenName: screenName,
            paymentHash: paymentHash)
        let alert = UIAlertController(
            title: "id_error".localized,
            message: prettyError.localized,
            preferredStyle: .alert)
        if AppSettings.shared.gdkSettings?.tor ?? false {
            alert.addAction(UIAlertAction(title: "Contact Support".localized, style: .default) { _ in
                self.showOpenSupportUrl(request)
            })
        } else {
            alert.addAction(UIAlertAction(title: "id_report".localized, style: .default) { _ in
                if let vc = UIStoryboard(name: "Dialogs", bundle: nil)
                    .instantiateViewController(withIdentifier: "DialogErrorViewController") as? DialogErrorViewController {
                    vc.request = request
                    vc.modalPresentationStyle = .overFullScreen
                    self.present(vc, animated: false, completion: nil)
                }
            })
        }
        alert.addAction(UIAlertAction(title: "id_cancel".localized, style: .cancel) { _ in })
        present(alert, animated: true)
    }
}

extension UIViewController {
    func hideKeyboardWhenTappedAround() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboardTappedAround))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc func dismissKeyboardTappedAround() {
        view.endEditing(true)
    }
}

@nonobjc extension UIViewController {
    func add(_ child: UIViewController, frame: CGRect? = nil) {
        addChild(child)

        if let frame = frame {
            child.view.frame = frame
        }

        view.addSubview(child.view)
        child.didMove(toParent: self)
    }

    func remove() {
        willMove(toParent: nil)
        view.removeFromSuperview()
        removeFromParent()
    }
    
    @MainActor
    public func presentAsync(_ vc: UIViewController, animated: Bool) async {
      await withCheckedContinuation { continuation in
        present(vc, animated: animated) {
          continuation.resume()
        }
      }
    }

    @MainActor
    public func dismissAsync(animated: Bool) async {
      await withCheckedContinuation { continuation in
        dismiss(animated: animated) {
          continuation.resume()
        }
      }
    }
}
