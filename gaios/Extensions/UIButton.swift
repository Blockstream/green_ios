import UIKit

private final class PrimaryLoadingButtonState {
    let indicator: UIActivityIndicatorView
    let storedImages: [(state: UIControl.State, image: UIImage?)]

    init(button: UIButton, indicator: UIActivityIndicatorView) {
        self.indicator = indicator
        self.storedImages = [
            (.normal, button.image(for: .normal)),
            (.disabled, button.image(for: .disabled)),
            (.highlighted, button.image(for: .highlighted)),
            (.selected, button.image(for: .selected))
        ]
    }
}

private enum ButtonAssociatedKeys {
    static var primaryLoadingState: UInt8 = 0
}

enum ButtonStyle {
    case primary
    case primaryGray
    case primaryDisabled
    case primaryLoading
    case outlined
    case outlinedGray
    case outlinedWhite
    case outlinedBlack
    case outlinedWhiteDisabled
    case inline
    case inlineGray
    case inlineWhite
    case inlineDisabled
    case destructive
    case destructiveOutlined
    case warnWhite
    case warnRed
    case qrEnlarge
    case underline(txt: String, color: UIColor)
    case blackWithImg
    case accentWithImg
    case sectionTitle
}

@IBDesignable
class DesignableButton: UIButton {}

extension UIButton {
    override open var isHighlighted: Bool {
        didSet {
            self.alpha = isHighlighted ? 0.6 : 1
        }
    }

    private var primaryLoadingState: PrimaryLoadingButtonState? {
        get {
            objc_getAssociatedObject(self, &ButtonAssociatedKeys.primaryLoadingState) as? PrimaryLoadingButtonState
        }
        set {
            objc_setAssociatedObject(
                self,
                &ButtonAssociatedKeys.primaryLoadingState,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    func insets(for content: UIEdgeInsets, image: CGFloat) {

        self.contentEdgeInsets = UIEdgeInsets(
            top: content.top,
            left: content.left,
            bottom: content.bottom,
            right: content.right + image
        )

        self.titleEdgeInsets = UIEdgeInsets(
            top: 0,
            left: image,
            bottom: 0,
            right: -image
        )
    }

    private func clearPrimaryLoadingStyle() {
        guard let state = primaryLoadingState else { return }

        state.indicator.stopAnimating()
        state.indicator.removeFromSuperview()
        state.storedImages.forEach { storedState in
            setImage(storedState.image, for: storedState.state)
        }
        primaryLoadingState = nil
    }

    private func applyPrimaryLoadingStyle() {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        indicator.color = titleColor(for: .disabled) ?? titleColor(for: .normal) ?? tintColor

        let state = PrimaryLoadingButtonState(button: self, indicator: indicator)
        primaryLoadingState = state

        let indicatorSize = indicator.intrinsicContentSize
        let imageSpacing: CGFloat = 8
        let placeholderSize = CGSize(
            width: max(indicatorSize.width, 20) + imageSpacing,
            height: max(indicatorSize.height, 20)
        )
        let placeholderImage = UIGraphicsImageRenderer(size: placeholderSize).image { _ in
            UIColor.clear.setFill()
            UIRectFill(CGRect(origin: .zero, size: placeholderSize))
        }

        [UIControl.State.normal, .disabled, .highlighted, .selected].forEach { state in
            setImage(placeholderImage, for: state)
        }

        addSubview(indicator)
        layoutIfNeeded()

        if let imageView = imageView {
            NSLayoutConstraint.activate([
                indicator.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
                indicator.centerYAnchor.constraint(equalTo: imageView.centerYAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                indicator.centerYAnchor.constraint(equalTo: centerYAnchor),
                indicator.centerXAnchor.constraint(
                    equalTo: centerXAnchor,
                    constant: -imageSpacing / 2
                )
            ])
        }

        indicator.startAnimating()
    }
}

final class CheckButton: UIButton {

    private let tapGesture = UITapGestureRecognizer()
    /// :nodoc:
    override func awakeFromNib() {
        super.awakeFromNib()

        setupUI()
    }

    deinit {
        removeGestureRecognizer(tapGesture)
    }

    /// :nodoc:
    override func draw(_ rect: CGRect) {
        super.draw(rect)

        setupUI()
    }

    /// Performs the first setup of the button.
    private func setupUI() {

        setTitle(nil, for: [.normal, .disabled, .selected])
        setBackgroundImage(UIImage(), for: .normal)
        setBackgroundImage(UIImage(named: "check"), for: .selected)
        layer.borderWidth = 1.0
        layer.borderColor = UIColor.customGrayLight().cgColor
        layer.cornerRadius = 3.0

        tapGesture.addTarget(self, action: #selector(didTap))
        addGestureRecognizer(tapGesture)
    }

    @objc private func didTap() {
      isSelected.toggle()
      sendActions(for: .touchUpInside)
    }
}

extension UIButton {

    func setStyle(_ type: ButtonStyle) {
        clearPrimaryLoadingStyle()
        titleLabel?.font = UIFont.systemFont(ofSize: 15.0, weight: .medium)
        cornerRadius = 8.0
        switch type {
        case .primary:
            backgroundColor = UIColor.gAccent()
            setTitleColor(UIColor.gBlackBg(), for: .normal)
            tintColor = UIColor.gBlackBg()
            isEnabled = true
        case .primaryGray:
            backgroundColor = UIColor.gW40()
            setTitleColor(.white, for: .normal)
            isEnabled = true
        case .primaryDisabled:
            backgroundColor = UIColor.customBtnOff()
            setTitleColor(UIColor.customGrayLight(), for: .normal)
            tintColor = UIColor.customGrayLight()
            isEnabled = false
        case .primaryLoading:
            backgroundColor = UIColor.gWarnCardBgBlue()
            setTitleColor(UIColor.gAccent(), for: .normal)
            setTitleColor(UIColor.gAccent(), for: .disabled)
            tintColor = UIColor.gBlackBg()
            isEnabled = false
            applyPrimaryLoadingStyle()
        case .outlined:
            backgroundColor = UIColor.clear
            setTitleColor(UIColor.gAccent(), for: .normal)
            tintColor = UIColor.gAccent()
            layer.borderWidth = 1.0
            layer.borderColor = UIColor.gAccent().cgColor
        case .outlinedGray:
            backgroundColor = UIColor.clear
            setTitleColor(UIColor.white, for: .normal)
            layer.borderWidth = 1.0
            layer.borderColor = UIColor.customGrayLight().cgColor
        case .outlinedBlack:
            backgroundColor = UIColor.clear
            setTitleColor(UIColor.white, for: .normal)
            layer.borderWidth = 1.0
            layer.borderColor = UIColor.black.cgColor
            setTitleColor(.black, for: .normal)
        case .outlinedWhite:
            backgroundColor = UIColor.clear
            setTitleColor(UIColor.white, for: .normal)
            layer.borderWidth = 1.0
            layer.borderColor = UIColor.white.cgColor
            isEnabled = true
        case .outlinedWhiteDisabled:
            backgroundColor = UIColor.clear
            setTitleColor(UIColor.white.withAlphaComponent(0.4), for: .normal)
            layer.borderWidth = 1.0
            layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
            isEnabled = false
        case .inline:
            backgroundColor = UIColor.clear
            setTitleColor(UIColor.gAccent(), for: .normal)
            isEnabled = true
        case .inlineGray:
            backgroundColor = UIColor.clear
            setTitleColor(UIColor.gW40(), for: .normal)
            isEnabled = true
        case .inlineWhite:
            backgroundColor = UIColor.clear
            setTitleColor(.white, for: .normal)
            isEnabled = true
        case .inlineDisabled:
            backgroundColor = UIColor.clear
            setTitleColor(UIColor.customGrayLight(), for: .normal)
            isEnabled = false
        case .destructive:
            backgroundColor = UIColor.customDestructiveRed()
            setTitleColor(.white, for: .normal)
        case .destructiveOutlined:
            backgroundColor = UIColor.clear
            setTitleColor(UIColor.customDestructiveRed(), for: .normal)
            borderWidth = 1.0
            borderColor = UIColor.customDestructiveRed()
        case .warnWhite:
            backgroundColor = .white
            setTitleColor(UIColor.gBlackBg(), for: .normal)
        case .warnRed:
            backgroundColor = .clear
            layer.borderWidth = 1.0
            layer.borderColor = UIColor.white.cgColor
            setTitleColor(.white, for: .normal)
        case .qrEnlarge:
            backgroundColor = UIColor.gGrayBtn()
        case .underline(let txt, let color):
            backgroundColor = UIColor.clear
            let attr: [NSAttributedString.Key: Any] = [
                .foregroundColor: color,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
            let attributeString = NSMutableAttributedString(
                    string: txt,
                    attributes: attr
                 )
            setAttributedTitle(attributeString, for: .normal)
        case .blackWithImg:
            backgroundColor = .black
            setTitleColor(.white, for: .normal)
            tintColor = .white
            layer.cornerRadius = 3.0
            titleLabel?.font = UIFont.systemFont(ofSize: 12.0, weight: .semibold)
        case .sectionTitle:
            setTitleColor(UIColor.gGrayTxt(), for: .normal)
            tintColor = UIColor.gGrayTxt()
            layer.cornerRadius = 0
            titleLabel?.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        case .accentWithImg:
            backgroundColor = .clear
            setTitleColor(UIColor.gAccent(), for: .normal)
            tintColor = UIColor.gAccent()
            layer.cornerRadius = 8.0
            layer.borderWidth = 1.0
            layer.borderColor = UIColor.gAccent().cgColor
            titleLabel?.font = UIFont.systemFont(ofSize: 14.0, weight: .semibold)
        }
    }
}
