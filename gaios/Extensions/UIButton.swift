import UIKit

enum ButtonStyle {
    case primary
    case primaryGray
    case primaryDisabled
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
        }
    }
}
