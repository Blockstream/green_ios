import UIKit

enum LabelStyle {
    case title
    case subTitle
    case subTitle24
    case titleCard
    case titleDialog
    case txt
    case txtBold
    case txtBigger
    case txtSmaller
    case txtSmallerBold
    case txtCard
    case txtSectionHeader
    case err
    case sectionTitle
    case fieldBigger
}

extension UILabel {
    
    func setStyle(_ type: LabelStyle) {
        switch type {
        case .title:
            textColor = .white
            font = UIFont.systemFont(ofSize: 26.0, weight: .bold)
        case .subTitle:
            textColor = .white
            font = UIFont.systemFont(ofSize: 20.0, weight: .semibold)
        case .subTitle24:
            textColor = .white
            font = UIFont.systemFont(ofSize: 24.0, weight: .bold)
        case .titleCard:
            textColor = .white
            font = UIFont.systemFont(ofSize: 16.0, weight: .semibold)
        case .titleDialog:
            textColor = .white
            font = UIFont.systemFont(ofSize: 18.0, weight: .bold)
        case .txt:
            textColor = .white.withAlphaComponent(0.6)
            font = UIFont.systemFont(ofSize: 14.0, weight: .regular)
        case .txtBold:
            textColor = .white
            font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        case .txtBigger:
            textColor = .white
            font = UIFont.systemFont(ofSize: 16.0, weight: .semibold)
        case .txtSmaller:
            textColor = .white
            font = UIFont.systemFont(ofSize: 12.0, weight: .regular)
        case .txtSmallerBold:
            textColor = .white
            font = UIFont.systemFont(ofSize: 12.0, weight: .bold)
        case .txtCard:
            textColor = UIColor.gGrayTxt()
            font = UIFont.systemFont(ofSize: 14.0, weight: .regular)
        case .txtSectionHeader:
            font = UIFont.systemFont(ofSize: 16.0, weight: .regular)
            textColor = UIColor.gGrayTxt()
        case .err:
            textColor = UIColor.customDestructiveRed()
            font = UIFont.systemFont(ofSize: 12.0, weight: .regular)
        case .sectionTitle:
            textColor = UIColor.gGrayTxt()
            font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        case .fieldBigger:
            textColor = .white
            font = UIFont.systemFont(ofSize: 21.0, weight: .semibold)
        }
    }
}

@IBDesignable
class DesignableLabel: UILabel {}

class CopyableLabel: DesignableLabel {

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(labelWasLongPressed))
        self.addGestureRecognizer(longPress)
        self.isUserInteractionEnabled = true
    }

    @objc func labelWasLongPressed(_ gesture: UIGestureRecognizer) {
        if gesture.state == .recognized,
            let gestureView = gesture.view,
            let superview = gestureView.superview,
            gestureView.becomeFirstResponder() {
            let copyMC = UIMenuController.shared
            copyMC.setTargetRect(gestureView.frame, in: superview)
            copyMC.setMenuVisible(true, animated: true)
        }
    }

    override func copy(_ sender: Any?) {
        UIPasteboard.general.string = text
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return (action == #selector(UIResponderStandardEditActions.copy(_:)))
    }
}
