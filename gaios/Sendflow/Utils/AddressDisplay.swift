import Foundation
import UIKit

enum AddressDisplayStyle {
    case `default`
    case txDetails
}

enum AddressDisplayAppearance {
    case light
    case dark
}

class AddressDisplay {

    static func configure(address: String,
                          textView: UITextView,
                          style: AddressDisplayStyle = .default,
                          truncate: Bool = false,
                          appearance: AddressDisplayAppearance = .dark,
                          wordsPerRow: Int = 4
    ) {
        var address = address
        var fontSize: CGFloat = 16.0
        var align: NSTextAlignment = .center
        if style == .txDetails {
            textView.textContainerInset = UIEdgeInsets(top: 1.0, left: 0.0, bottom: 0.0, right: 0.0)
            fontSize = 12.0
            align = .right
        }
        let rowL = 4 * wordsPerRow + (wordsPerRow - 1) * 2
        var visibleAddress = ""
        var rangeA = NSRange() // all chars
        var rangeH = NSRange() // head chars
        var rangeT = NSRange() // tail chars
        var rangeP = NSRange() // pad chars

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = align

        let shouldTruncate = truncate && address.count > 4 * wordsPerRow * 3 // exceeds 3 rows

        if shouldTruncate {
            address = String(address.prefix(4 * wordsPerRow)) + String(address.suffix(4 * wordsPerRow))
        }
        for i in 0...address.count {
            if i > 0 && i < address.count {
                if i % 4 == 0 && i % (4 * wordsPerRow) != 0 {
                    visibleAddress.append("  ")
                }
                if i % (4 * wordsPerRow) == 0 {
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

        if shouldTruncate {
            let rows = visibleAddress.components(separatedBy: "\n")
            if rows.count == 2, let rowF = rows.first, let rowL = rows.last {
                visibleAddress = rowF + "\n" + "⋯\n" + rowL
                rangeA.location = 0
                rangeA.length = visibleAddress.count
                rangeH.location = 0
                rangeH.length = 8 + 2
                rangeT.location = visibleAddress.count - (8 + 2)
                rangeT.length = 8 + 2
                rangeP.length = visibleAddress.count
                rangeP.length = 0
            }
        }

        let attrS = NSMutableAttributedString(string: visibleAddress)
        attrS.addAttribute(.paragraphStyle, value: paragraph, range: rangeA)
        switch appearance {
        case .light:
            attrS.setColor(color: .black, forText: visibleAddress)
        case .dark:
            attrS.setColor(color: .white, forText: visibleAddress)
        }
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
