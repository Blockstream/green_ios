import Foundation
import UIKit

enum AddressDisplayStyle {
    case `default`
    case txDetails
}

class AddressDisplay {

    static func configure(address: String, textView: UITextView, style: AddressDisplayStyle = .default) {

        var fontSize: CGFloat = 16.0
        var align: NSTextAlignment = .center
        if style == .txDetails {
            textView.textContainerInset = UIEdgeInsets(top: 1.0, left: 0.0, bottom: 0.0, right: 0.0)
            fontSize = 12.0
            align = .right
        }
        let rowL = 4 * 4 + 3 * 2
        var visibleAddress = ""
        var rangeA = NSRange() // all chars
        var rangeH = NSRange() // head chars
        var rangeT = NSRange() // tail chars
        var rangeP = NSRange() // pad chars

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = align

        for i in 0...address.count {
            if i > 0 && i < address.count {
                if i % 4 == 0 && i % 16 != 0 {
                    visibleAddress.append("  ")
                }
                if i % 16 == 0 {
                    visibleAddress.append("\n")
                }
            }
            visibleAddress.append(address[i..<i+1])
        }
        let lastRow = visibleAddress.components(separatedBy: "\n")
        if address.count > 8 {
            rangeH.location = 0
            rangeH.length = 8 + 2
            let res = address.count % 4
            let tail = 4 + (res == 0 ? 4 : res) + 2
            rangeT.location = visibleAddress.count - tail
            rangeT.length = tail
        }

        rangeA.location = 0
        rangeA.length = visibleAddress.count

        let pad = String(repeating: ".", count: rowL - (lastRow.last?.count ?? 0))
        rangeP.length = pad.count
        rangeP.location = visibleAddress.count

        visibleAddress += pad
        let attrS = NSMutableAttributedString(string: visibleAddress)
        attrS.addAttribute(.paragraphStyle, value: paragraph, range: rangeA)
        attrS.setColor(color: .white, forText: visibleAddress)
        attrS.setFont(font: .monospacedSystemFont(ofSize: fontSize, weight: .regular), stringValue: visibleAddress)

        if visibleAddress.count > 10 {

            attrS.addAttribute(NSAttributedString.Key.foregroundColor,
                               value: UIColor.gGreenMatrix(),
                               range: rangeH)
            attrS.addAttribute(NSAttributedString.Key.foregroundColor,
                               value: UIColor.gGreenMatrix(),
                               range: rangeT)
            attrS.addAttribute(NSAttributedString.Key.foregroundColor,
                               value: UIColor.clear,
                               range: rangeP)
        }
        textView.attributedText = attrS
    }
}
