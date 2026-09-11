import UIKit

enum StatusPageMessageHelper {
    static let delaySeconds: TimeInterval = 15.0
    static let delayMessage = "Login is taking longer than usual\n\nMore information: status.blockstream.com"
    static let url = URL(string: "https://status.blockstream.com")

    private static let moreInfoText = "More information: status.blockstream.com"
    private static let host = "status.blockstream.com"

    static func styleMessage(_ message: NSAttributedString) -> (message: NSAttributedString, statusRange: NSRange?) {
        let styledMessage = NSMutableAttributedString(attributedString: message)
        let fullText = styledMessage.string as NSString
        let moreInfoRange = fullText.range(of: moreInfoText)
        let hostRange = fullText.range(of: host)

        if moreInfoRange.location != NSNotFound {
            styledMessage.addAttribute(
                .font,
                value: UIFont.systemFont(ofSize: 11, weight: .regular),
                range: moreInfoRange
            )
        }

        var statusRange: NSRange?
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
        }

        return (styledMessage, statusRange)
    }

    static func didTap(label: UILabel,
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

    private static func statusLinkIconAttributedString() -> NSAttributedString? {
        guard let image = UIImage(named: "ic_squared_out") else { return nil }

        let attachment = NSTextAttachment()
        attachment.image = image.withTintColor(UIColor.gAccent(), renderingMode: .alwaysOriginal)
        attachment.bounds = CGRect(x: 6, y: -4, width: 18, height: 18)
        return NSAttributedString(attachment: attachment)
    }
}
