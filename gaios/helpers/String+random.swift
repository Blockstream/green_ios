import Foundation
import UIKit

extension String {

    static var chars: [Character] = {
        return "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".map({$0})
    }()

    static func random(length: Int) -> String {
        var partial: [Character] = []

        for _ in 0..<length {
            let rand = Int(arc4random_uniform(UInt32(chars.count)))
            partial.append(chars[rand])
        }

        return String(partial)
    }

    static func toBtc(satoshi: UInt64? = nil, value: String? = nil, fiat: String? = nil, fiatCurrency: String? = nil, fromType: DenominationType? = nil, toType: DenominationType? = nil) -> String? {
        var dict = [String: Any]()
        if (satoshi != nil) { dict["satoshi"] = satoshi }
        if (fiat != nil) { dict["fiat"] = fiat }
        if (fiatCurrency != nil) { dict["fiat_currency"] = fiatCurrency }
        if (value != nil) { dict[getDenominationKey(fromType)] = value }
        let res = try! getSession().convertAmount(input: dict)
        if (toType != nil) { return res![getDenominationKey(toType)] as? String }
        return String(format: "%d", res!["satoshi"] as! Int)
    }

    static func toFiat(satoshi: UInt64? = nil, value: String? = nil, fromType: DenominationType? = nil) -> String? {
        var dict = [String: Any]()
        if (satoshi != nil) { dict["satoshi"] = satoshi }
        if (value != nil) { dict[getDenominationKey(fromType)] = value }
        let res = try! getSession().convertAmount(input: dict)
        return res!["fiat"] as? String
    }

    static func formatBtc(satoshi: UInt64? = nil, value: String? = nil, fromType: DenominationType? = nil, toType: DenominationType? = nil) -> String {
        let fType = fromType ?? SettingsStore.shared.getDenominationSettings()
        let tType = toType ?? SettingsStore.shared.getDenominationSettings()
        let text: String = toBtc(satoshi: satoshi, value: value, fromType: fType, toType: tType)!
        return String(format: "%@ %@", text, tType.rawValue)
    }

    static func formatFiat(satoshi: UInt64? = nil, fiat: String? = nil, fiatCurrency: String? = nil) -> String {
        let currency = fiatCurrency ?? SettingsStore.shared.getCurrencyString()
        let value = fiat ?? toFiat(satoshi: satoshi, value: fiatCurrency)!
        return String(format: "%@ %@", value, currency)
    }

    func heightWithConstrainedWidth(width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [NSAttributedStringKey.font: font], context: nil)
        return boundingBox.height
    }

}

extension NSMutableAttributedString {

    func setColor(color: UIColor, forText stringValue: String) {
        let range: NSRange = self.mutableString.range(of: stringValue, options: .caseInsensitive)
        self.addAttribute(NSAttributedStringKey.foregroundColor, value: color, range: range)
    }

    func setFont(font: UIFont, stringValue: String) {
        let range: NSRange = self.mutableString.range(of: stringValue, options: .caseInsensitive)
        self.addAttributes([NSAttributedStringKey.font: font], range: range)
    }

}

extension URL {
    public var queryItems: [String: String] {
        var params = [String: String]()
        return URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .reduce([:], { (_, item) -> [String: String] in
                params[item.name] = item.value
                return params
            }) ?? [:]
    }
}
