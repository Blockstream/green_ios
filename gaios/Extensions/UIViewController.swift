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
            alert.addAction(UIAlertAction(title: "id_continue".localized, style: .cancel) { _ in completion() })
            self.present(alert, animated: true, completion: completion)
        }
    }

    @MainActor
    func showError(_ message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "id_error".localized, message: message.localized, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "id_continue".localized, style: .cancel) { _ in })
            self.present(alert, animated: true, completion: nil)
        }
    }
    @MainActor
    func showError(_ err: Error) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "id_error".localized, message: err.description().localized, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "id_continue".localized, style: .cancel) { _ in })
            self.present(alert, animated: true, completion: nil)
        }
    }

    @MainActor
    func showOpenSupportUrl(_ request: ZendeskErrorRequest) {
        Task {
            let url = await ZendeskSdk.shared.createNewTicketUrl(req: request)
            if let url = url {
                SafeNavigationManager.shared.navigate(url)
            }
        }
    }

    @MainActor
    func presentContactUsViewController(request: ZendeskErrorRequest, isPush: Bool = false) {
        if AppSettings.shared.gdkSettings?.tor ?? false {
            self.showOpenSupportUrl(request)
            return
        }
        if let vc = UIStoryboard(name: "HelpCenter", bundle: nil)
            .instantiateViewController(withIdentifier: "ContactUsViewController") as? ContactUsViewController {
            vc.request = request
            if isPush == false {
                vc.modalPresentationStyle = .overFullScreen
                self.present(vc, animated: true, completion: nil)
            } else {
                navigationController?.pushViewController(vc, animated: true)
            }
        }
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

extension UIViewController {

    var backgroundTag: Int { 12345 }

    func getBackgroundView() -> UIView {
        if let backgroundView = view.viewWithTag(backgroundTag) {
            return backgroundView
        } else {
            let backgroundView = UIView()
            backgroundView.tag = backgroundTag
            backgroundView.backgroundColor = UIColor.gBlackBg().withAlphaComponent(0.8)
            return backgroundView
        }
    }
    func getProgressView() -> ProgressView {
        if let progressView = getBackgroundView().viewWithTag(ProgressView.tag) as? ProgressView {
            return progressView
        } else {
            let progressView = ProgressView()
            progressView.tag = ProgressView.tag
            NSLayoutConstraint.activate([
                progressView.widthAnchor.constraint(equalToConstant: 24),
                progressView.heightAnchor.constraint(equalToConstant: 24)
            ])
            return progressView
        }
    }

    @MainActor
    @objc func startAnimating(message: String = "") {
        let backgroundView = getBackgroundView()
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        let progressView = getProgressView()
        progressView.isAnimating = true
        progressView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
            progressView.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor)
        ])
    }

    @MainActor
    @objc func stopAnimating() {
        let backgroundView = getBackgroundView()
        let progressView = getProgressView()
        progressView.isAnimating = false
        progressView.removeFromSuperview()
        backgroundView.removeFromSuperview()
    }
}

extension UIViewController {
    static func instantiateViewController<K>(storyboard: String, identifier: String) -> K? {
        let storyboard = UIStoryboard(name: storyboard, bundle: nil)
        return storyboard.instantiateViewController(withIdentifier: identifier) as? K
    }
}
extension UIViewController {
    func add_child(_ child: UIViewController) {
        addChild(child)
        view.addSubview(child.view)
        child.didMove(toParent: self)
    }

    func remove_child() {
        guard parent != nil else {
            return
        }

        willMove(toParent: nil)
        view.removeFromSuperview()
        removeFromParent()
    }
}
