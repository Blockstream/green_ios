import Foundation
import UIKit

class Common {

    static func obfuscate(color: UIColor, size: CGFloat, length: Int = 1) -> NSAttributedString {
        let lblText = NSMutableAttributedString()
        for _ in 1...length {
            lblText.append(Common().singleAttachment(color: color, size: size))
        }
        return lblText
    }

    private func singleAttachment(color: UIColor, size: Double) -> NSAttributedString {

        if #available(iOS 13.0, *) {
            let attachment = NSTextAttachment()
            let image = UIImage(systemName: "asterisk")?
                .withTintColor(color)
            attachment.image = image
            attachment.bounds = CGRect(x: 0.0, y: 0.0, width: size, height: size)
            let fullString = NSMutableAttributedString(string: "")
            fullString.append(NSAttributedString(attachment: attachment))
            fullString.append(NSAttributedString(attachment: attachment))
            fullString.append(NSAttributedString(attachment: attachment))
            fullString.append(NSAttributedString(attachment: attachment))
            return fullString
        } else {
            return NSAttributedString()
        }
    }
}
