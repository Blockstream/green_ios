import UIKit
import Foundation
import RiveRuntime

@IBDesignable
class Loader: UIView {

    let loadingIndicator: ProgressView = {
        let progress = ProgressView()
        progress.translatesAutoresizingMaskIntoConstraints = false
        return progress
    }()

    @IBOutlet weak var loaderPlaceholder: UIView!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var rectangle: UIView!
    @IBOutlet weak var animateView: UIView!

    static let tag = 0x70726f6772657373
    var message: NSMutableAttributedString? {
        didSet { self.lblHint.attributedText = self.message }
    }
    var isRive = false

    init() {
        super.init(frame: .zero)
        tag = Loader.tag
        translatesAutoresizingMaskIntoConstraints = false
        setup()
        lblHint.setStyle(.txtBigger)
        rectangle.backgroundColor = UIColor.gBlackBg().withAlphaComponent(0.9)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func activateConstraints(in window: UIWindow) {
        NSLayoutConstraint.activate([
            self.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            self.trailingAnchor.constraint(equalTo: window.trailingAnchor),
            self.topAnchor.constraint(equalTo: window.topAnchor),
            self.bottomAnchor.constraint(equalTo: window.bottomAnchor)
        ])
    }

    func start() {
        self.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor
                .constraint(equalTo: self.loaderPlaceholder.centerXAnchor),
            loadingIndicator.centerYAnchor
                .constraint(equalTo: self.loaderPlaceholder.centerYAnchor),
            loadingIndicator.widthAnchor.constraint(equalToConstant: 24),
            loadingIndicator.heightAnchor.constraint(equalToConstant: 24)
        ])

        if !isRive {
            loadingIndicator.isAnimating = true
        } else {
            let riveView = RiveModel.animationRocket.createRiveView()
            animateView.addSubview(riveView)
            riveView.frame = CGRect(x: 0.0, y: 0.0, width: animateView.frame.width, height: animateView.frame.height)
        }
    }

    func stop() {
        loadingIndicator.isAnimating = false
    }

    static func resume() {
        if let window = UIApplication.shared.windows.filter({ $0.isKeyWindow }).first {
            if let loader = window.viewWithTag(Loader.tag) as? Loader {
                if !loader.isRive {
                    loader.loadingIndicator.isAnimating = true
                }
            }
        }
    }
}

extension UIViewController {

    @objc var loader: Loader? {
        get {
            if let window = UIApplication.shared.windows.filter({ $0.isKeyWindow }).first {
                return window.viewWithTag(Loader.tag) as? Loader
            }
            return nil
        }
    }

    @MainActor
    func startLoader(message: String = "", isRive: Bool = false) {
        startLoader(message: NSMutableAttributedString(string: message), isRive: isRive)
    }

    @MainActor
    @objc func startLoader(message: NSMutableAttributedString, isRive: Bool = false) {
        if let window = UIApplication.shared.windows.filter({ $0.isKeyWindow }).first {
            if loader == nil {
                let loader = Loader()
                loader.isRive = isRive
                window.addSubview(loader)
                loader.message = message
                loader.activateConstraints(in: window)
                if !(loader.loadingIndicator.isAnimating) {
                    loader.start()
                }
            }
            loader?.message = message
        }
    }

    @MainActor
    func updateLoader(message: String = "") {
        loader?.message = NSMutableAttributedString(string: message)
    }

    func progressLoaderMessage(title: String, subtitle: String) -> NSMutableAttributedString {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white
        ]
        let hashAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.customGrayLight(),
            .font: UIFont.systemFont(ofSize: 16)
        ]
        let hint = "\n\n" + subtitle
        let attributedTitleString = NSMutableAttributedString(string: title)
        attributedTitleString.setAttributes(titleAttributes, for: title)
        let attributedHintString = NSMutableAttributedString(string: hint)
        attributedHintString.setAttributes(hashAttributes, for: hint)
        attributedTitleString.append(attributedHintString)
        return attributedTitleString
    }

    @MainActor
    @objc func stopLoader() {
        UIApplication.shared.windows.forEach { window in
            window.subviews.forEach { view in
                if let loader = view.viewWithTag(Loader.tag) as? Loader {
                    loader.stop()
                    loader.removeFromSuperview()
                }
            }
        }
    }
}
