import Foundation
import UIKit

extension String {

    public static var chars: [Character] = {
        return "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".map({$0})
    }()

    public static func random(length: Int) -> String {
        var partial: [Character] = []

        for _ in 0..<length {
            let rand = Int(arc4random_uniform(UInt32(chars.count)))
            partial.append(chars[rand])
        }

        return String(partial)
    }

    public func heightWithConstrainedWidth(width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [NSAttributedString.Key.font: font], context: nil)
        return boundingBox.height
    }

    public func localeFormattedString(_ digits: Int) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.roundingMode = .down
        numberFormatter.maximumFractionDigits = digits
        numberFormatter.minimumFractionDigits = digits
        numberFormatter.locale = Locale(identifier: "en_EN")
        if let number = numberFormatter.number(from: self) {
            numberFormatter.locale = Locale.current
            if let localFormattedString = numberFormatter.string(from: number) {
                return localFormattedString
            }
        }
        return self
    }
    public func unlocaleFormattedString(_ digits: Int = 8) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.roundingMode = .down
        numberFormatter.maximumFractionDigits = digits
        numberFormatter.minimumFractionDigits = digits
        numberFormatter.locale = Locale.current
        if let number = numberFormatter.number(from: self) {
            numberFormatter.groupingSeparator = ""
            numberFormatter.locale = Locale(identifier: "en_EN")
            if let localFormattedString = numberFormatter.string(from: number) {
                return localFormattedString
            }
        }
        return self
    }

    public func separated(by separator: String = " ", every stride: Int = 4) -> String {
        return enumerated()
            .map { $0.isMultiple(of: stride) && ($0 != 0) ? "\(separator)\($1)" : String($1) }
            .joined()
    }
}

extension DataProtocol {
    public var data: Data { .init(self) }
    public var hex: String { map { .init(format: "%02x", $0) }.joined() }
}

extension StringProtocol {
    public var hex: [UInt8] {
        var start = self.startIndex
        return (0..<count/2)
            .compactMap { _ in
                let end = index(after: start)
                defer { start = index(after: end) }
                return UInt8(self[start...end], radix: 16)
        }
    }
}

extension Optional where Wrapped == String {
    public var isNilOrEmpty: Bool {
        if let strongSelf = self, !strongSelf.isEmpty {
            return false
        }
        return true
    }
    public var isNotEmpty: Bool {
        return !isNilOrEmpty
    }
}

extension NSMutableAttributedString {

    public func setColor(color: UIColor, forText stringValue: String) {
        let range: NSRange = self.mutableString.range(of: stringValue, options: .caseInsensitive)
        self.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: range)
    }

    public func setFont(font: UIFont, stringValue: String) {
        let range: NSRange = self.mutableString.range(of: stringValue, options: .caseInsensitive)
        self.addAttributes([NSAttributedString.Key.font: font], range: range)
    }

    public func setAttributes(_ attrs: [NSAttributedString.Key: Any], for substring: String) {
        let range: NSRange = self.mutableString.range(of: substring, options: .caseInsensitive)
        self.addAttributes(attrs, range: range)
    }
}

extension StringProtocol {
    public var firstUppercased: String { return prefix(1).uppercased() + dropFirst() }
    public var firstCapitalized: String { return prefix(1).capitalized + dropFirst() }
}

extension String {
    public var htmlDecoded: String {
        let decoded = try? NSAttributedString(data: Data(utf8), options: [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ], documentAttributes: nil).string

        return decoded ?? self
    }
}

extension String {
    public func versionCompare(_ otherVersion: String) -> ComparisonResult {
        return self.compare(otherVersion, options: .numeric)
    }
}

extension String {
    public func isValidEmailAddr() -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: self)
    }
}

extension String {
    public func isCode6Digits() -> Bool {
        let codeRegEx = "^[0-9]{6,6}"
        let codePred = NSPredicate(format: "SELF MATCHES %@", codeRegEx)
        return codePred.evaluate(with: self)
    }
}

extension String {
    public subscript(_ range: CountableRange<Int>) -> String {
        let start = index(startIndex, offsetBy: max(0, range.lowerBound))
        let end = index(start, offsetBy: min(self.count - range.lowerBound,
                                             range.upperBound - range.lowerBound))
        return String(self[start..<end])
    }

    public subscript(_ range: CountablePartialRangeFrom<Int>) -> String {
        let start = index(startIndex, offsetBy: max(0, range.lowerBound))
         return String(self[start...])
    }
}
