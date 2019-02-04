import Foundation
import UIKit

class Toast {
    static let SHORT_DURATION: DispatchTimeInterval = DispatchTimeInterval.milliseconds(2000)
    static let LONG_DURATION: DispatchTimeInterval = DispatchTimeInterval.milliseconds(3500)
    static let padding = CGFloat(20)

    class Label: UILabel {
        override func drawText(in rect: CGRect) {
            super.drawText(in: UIEdgeInsetsInsetRect(rect, UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)))
        }
    }

    static func show(_ message: String) {
        Toast.show(message, timeout: Toast.SHORT_DURATION)
    }

    static func show(_ message: String, timeout: DispatchTimeInterval) {
        let window = UIApplication.shared.keyWindow!
        let v = UIView(frame: window.bounds)

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = message
        label.lineBreakMode = NSLineBreakMode.byWordWrapping
        label.numberOfLines = 0
        label.textAlignment = .center
        label.backgroundColor = UIColor.init(red: 0xca/0xff, green: 0xd1/0xff, blue: 0xd7/0xff, alpha: 1)
        label.textColor = UIColor.init(red: 0x4a/0xff, green: 0x4a/0xff, blue: 0x4a/0xff, alpha: 1)
        label.cornerRadius = 4
        label.borderWidth = 1
        label.clipsToBounds = true
        label.layer.masksToBounds = true

        // Add label to view
        v.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        v.addSubview(label)
        window.addSubview(v)

        // Set constraints
        let estimateRect = label.attributedText?.boundingRect(with: v.frame.size, options: [.usesFontLeading, .usesLineFragmentOrigin], context: nil)
        let estimateHeight = estimateRect!.height + padding * 2
        let maxWidth = CGFloat(240)
        let estimateWidth = min(maxWidth, v.frame.width - padding * 2 * 2)

        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: estimateHeight).isActive = true
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1, constant: estimateWidth).isActive = true
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: v, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: v, attribute: NSLayoutAttribute.centerY, multiplier: 1, constant: 0).isActive = true

        // Set autohidden after timeout
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + timeout) {
            v.removeFromSuperview()
        }
    }
}
