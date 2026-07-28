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
    @IBOutlet weak var bottomIconImageView: UIImageView!
    
    static let tag = 0x70726f6772657373
    var message: NSMutableAttributedString? {
        didSet { self.lblHint.attributedText = self.message }
    }
    var bottomIcon: UIImage? {
        didSet {
            bottomIconImageView?.image = bottomIcon
            bottomIconImageView?.isHidden = (bottomIcon == nil)
        }
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
        
        if bottomIcon != nil {
            self.bottomIconImageView.alpha = 1.0
            
            UIView.animate(withDuration: 0.5, delay: 0, options: [.repeat, .autoreverse], animations: {
                self.bottomIconImageView.alpha = 0.75
            })
        }
    }

    func stop() {
        loadingIndicator.isAnimating = false
        bottomIconImageView.layer.removeAllAnimations()
        bottomIconImageView.alpha = 1.0
    }

    static func resume() {
        if let window = UIApplication.activeKeyWindow {
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
            if let window = UIApplication.activeKeyWindow {
                return window.viewWithTag(Loader.tag) as? Loader
            }
            return nil
        }
    }

    @MainActor
    func startLoader(message: String = "", isRive: Bool = false, bottomIcon: UIImage? = nil) {
        startLoader(message: NSMutableAttributedString(string: message), isRive: isRive, bottomIcon: bottomIcon)
    }

    @MainActor
    @objc func startLoader(message: NSMutableAttributedString, isRive: Bool = false, bottomIcon: UIImage? = nil) {
        if let window = UIApplication.activeKeyWindow {
            if loader == nil {
                let loader = Loader()
                loader.isRive = isRive
                loader.bottomIcon = bottomIcon
                window.addSubview(loader)
                loader.message = message
                loader.activateConstraints(in: window)
                if !(loader.loadingIndicator.isAnimating) {
                    loader.start()
                }
            }
            loader?.message = message
            loader?.bottomIcon = bottomIcon
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
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
            .flatMap { $0.windows }
            .forEach { window in
            window.subviews.forEach { view in
                if let loader = view.viewWithTag(Loader.tag) as? Loader {
                    loader.stop()
                    loader.removeFromSuperview()
                }
            }
        }
    }
}
