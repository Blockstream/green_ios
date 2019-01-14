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

    static func toBtc(satoshi: UInt64) -> String {
        guard let settings = getGAService().getSettings() else { return "" }
        guard let res = try! getSession().convertAmount(input: ["satoshi" : satoshi]) else { return "" }
        return String(format: "%@ %@", res[settings.denomination.rawValue] as! String, settings.denomination.toString())
    }

    static func toFiat(satoshi: UInt64) -> String {
        guard let settings = getGAService().getSettings() else { return "" }
        guard let res = try! getSession().convertAmount(input: ["satoshi" : satoshi]) else { return "" }
        return String(format: "%@ %@", res["fiat"] as! String, settings.getCurrency())
    }

    static func toSatoshi(fiat: String) -> UInt64 {
        guard let res = try! getSession().convertAmount(input: ["fiat" : fiat]) else { return 0 }
        return res["satoshi"] as! UInt64
    }

    static func toSatoshi(amount: String) -> UInt64 {
        guard let settings = getGAService().getSettings() else { return 0 }
        guard let res = try! getSession().convertAmount(input: [settings.denomination.rawValue : amount]) else { return 0 }
        return res["satoshi"] as! UInt64
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
