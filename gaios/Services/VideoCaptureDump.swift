import UIKit

final class VideoCaptureDump {
    private weak var hostViewController: UIViewController?
    private var overlay: UIView?
    // NOTE: screen recording protection
    func install(on viewController: UIViewController, preemptive: Bool = false) {
        uninstall()
        hostViewController = viewController
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenCaptureChanged),
            name: UIScreen.capturedDidChangeNotification,
            object: nil
        )
        updateOverlay()
    }
    func uninstall() {
        NotificationCenter.default.removeObserver(self, name: UIScreen.capturedDidChangeNotification, object: nil)
        removeOverlay()
        hostViewController = nil
    }
    @objc private func screenCaptureChanged() {
        updateOverlay()
    }
    private func updateOverlay() {
        DispatchQueue.main.async {
            guard let vc = self.hostViewController, vc.isViewLoaded else {
                self.removeOverlay()
                return
            }
            if UIScreen.main.isCaptured {
                self.showOverlay(in: vc)
            } else {
                self.removeOverlay()
            }
        }
    }
    private func container(for vc: UIViewController) -> UIView {
        if let window = vc.view.window {
            return window
        }
        if let navView = vc.navigationController?.view {
            return navView
        }
        return vc.view
    }
    private func showOverlay(in vc: UIViewController) {
        let containerView = container(for: vc)
        if let existing = overlay {
            if existing.superview !== containerView {
                existing.removeFromSuperview()
                existing.frame = containerView.bounds
                existing.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                containerView.addSubview(existing)
            }
            return
        }
        let shield = UIView(frame: containerView.bounds)
        shield.backgroundColor = .black
        shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        shield.isUserInteractionEnabled = false
        let label = UILabel()
        label.text = "Screen recording not allowed".localized
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        shield.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: shield.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: shield.centerYAnchor)
        ])
        containerView.addSubview(shield)
        containerView.bringSubviewToFront(shield)
        overlay = shield
    }
    private func removeOverlay() {
        overlay?.removeFromSuperview()
        overlay = nil
    }
    deinit {
        uninstall()
    }
}
