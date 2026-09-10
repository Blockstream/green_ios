import UIKit
import Foundation
import RiveRuntime

enum LoaderScope {
    case unknown
    case login
    case create
}
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
    private var statusScopeTimer: Timer?
    private let statusDelayMessage = "Login is taking longer than usual\n\nMore information: status.blockstream.com"
    private let statusMoreInfoText = "More information: status.blockstream.com"
    private let statusHost = "status.blockstream.com"
    private let statusURL = URL(string: "https://status.blockstream.com")
    private var statusRange: NSRange?
    private var statusTimerTime = 15.0
    var message: NSMutableAttributedString? {
        didSet { applyStyledMessage() }
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
        lblHint.isUserInteractionEnabled = true
        lblHint.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onHintTap(_:))))
        rectangle.backgroundColor = UIColor.gBlackBg().withAlphaComponent(0.9)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        invalidateStatusScopeTimer()
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
        invalidateStatusScopeTimer()
        bottomIconImageView.layer.removeAllAnimations()
        bottomIconImageView.alpha = 1.0
    }

    func scheduleStatusScopeTimerIfNeeded(scope: LoaderScope) {
        invalidateStatusScopeTimer()
        guard scope == .login || scope == .create else { return }
        statusScopeTimer = Timer.scheduledTimer(withTimeInterval: statusTimerTime, repeats: false) { [weak self] timer in
            timer.invalidate()
            guard let self = self else { return }
            self.statusScopeTimer = nil
            Task { @MainActor in
                self.message = NSMutableAttributedString(string: self.statusDelayMessage)
            }
        }
    }

    private func invalidateStatusScopeTimer() {
        statusScopeTimer?.invalidate()
        statusScopeTimer = nil
    }

    private func applyStyledMessage() {
        guard let message else {
            statusRange = nil
            lblHint.attributedText = nil
            return
        }

        let styledMessage = NSMutableAttributedString(attributedString: message)
        let fullText = styledMessage.string as NSString
        let moreInfoRange = fullText.range(of: statusMoreInfoText)
        let hostRange = fullText.range(of: statusHost)

        if moreInfoRange.location != NSNotFound {
            styledMessage.addAttribute(
                .font,
                value: UIFont.systemFont(ofSize: 11, weight: .regular),
                range: moreInfoRange
            )
        }

        if hostRange.location != NSNotFound {
            styledMessage.addAttributes([
                .foregroundColor: UIColor.gAccent(),
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ], range: hostRange)

            if let linkIcon = statusLinkIconAttributedString() {
                styledMessage.insert(linkIcon, at: hostRange.location + hostRange.length)
                statusRange = NSRange(location: hostRange.location, length: hostRange.length + linkIcon.length)
            } else {
                statusRange = hostRange
            }
        } else {
            statusRange = nil
        }

        lblHint.attributedText = styledMessage
    }

    private func statusLinkIconAttributedString() -> NSAttributedString? {
        guard let image = UIImage(named: "ic_squared_out") else { return nil }

        let attachment = NSTextAttachment()
        attachment.image = image.withTintColor(UIColor.gAccent(), renderingMode: .alwaysOriginal)
        attachment.bounds = CGRect(x: 6, y: -4, width: 18, height: 18)
        return NSAttributedString(attachment: attachment)
    }

    @objc private func onHintTap(_ gesture: UITapGestureRecognizer) {
        guard let range = statusRange,
              let attributedText = lblHint.attributedText,
              let url = statusURL else {
            return
        }

        if didTap(label: lblHint, inRange: range, attributedText: attributedText, gesture: gesture) {
            SafeNavigationManager.shared.navigate(url)
        }
    }

    private func didTap(label: UILabel,
                        inRange targetRange: NSRange,
                        attributedText: NSAttributedString,
                        gesture: UITapGestureRecognizer) -> Bool {
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: .zero)
        let textStorage = NSTextStorage(attributedString: attributedText)

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = label.lineBreakMode
        textContainer.maximumNumberOfLines = label.numberOfLines
        textContainer.size = label.bounds.size

        let tapLocation = gesture.location(in: label)
        let textBounds = layoutManager.usedRect(for: textContainer)
        let xOffset = (label.bounds.width - textBounds.width) * 0.5 - textBounds.origin.x
        let yOffset = (label.bounds.height - textBounds.height) * 0.5 - textBounds.origin.y
        let locationInTextContainer = CGPoint(x: tapLocation.x - xOffset, y: tapLocation.y - yOffset)

        let characterIndex = layoutManager.characterIndex(for: locationInTextContainer,
                                                          in: textContainer,
                                                          fractionOfDistanceBetweenInsertionPoints: nil)
        return NSLocationInRange(characterIndex, targetRange)
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
    func startLoader(message: String = "",
                     isRive: Bool = false,
                     bottomIcon: UIImage? = nil,
                     scope: LoaderScope = .unknown) {
        startLoader(message: NSMutableAttributedString(string: message),
                    isRive: isRive,
                    bottomIcon: bottomIcon,
                    scope: scope)
    }

    @MainActor
    func startLoader(message: NSMutableAttributedString,
                     isRive: Bool = false,
                     bottomIcon: UIImage? = nil,
                     scope: LoaderScope = .unknown) {
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
            loader?.scheduleStatusScopeTimerIfNeeded(scope: scope)
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
