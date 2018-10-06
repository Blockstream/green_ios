//
//  String+random.swift
//  gaios
//
//  Created by Strahinja Markovic on 6/19/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

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

    static func satoshiToBTC(satoshi: String) -> String {
        let satoshi: Double = Double(satoshi)!
        let dSettings = SettingsStore.shared.getDenominationSettings()
        var div: Double = 100000000
        if (dSettings == SettingsStore.shared.denominationPrimary) {
            div = 100000000
        } else if (dSettings == SettingsStore.shared.denominationMilli) {
            div = 100000
        } else if (dSettings == SettingsStore.shared.denominationMicro) {
            div = 100
        }
        let btc = satoshi / div
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 6
        var result: String = formatter.string(from: NSNumber(value: btc))!
        if (btc < 1 && btc > 0) {
            result = "0" + result
        } else if (btc < 0 && btc > -1) {
            result = "-0" + String(result.dropFirst())
        } else if ( btc == 0) {
            result = "0"
        }
        return result
    }

    static func satoshiToBTC(satoshi: Int) -> String {
        let satoshi: Double = Double(satoshi)
        let dSettings = SettingsStore.shared.getDenominationSettings()
        var div: Double = 100000000
        if (dSettings == SettingsStore.shared.denominationPrimary) {
            div = 100000000
        } else if (dSettings == SettingsStore.shared.denominationMilli) {
            div = 100000
        } else if (dSettings == SettingsStore.shared.denominationMicro) {
            div = 100
        }
        let btc = satoshi / div
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 6
        var result: String = formatter.string(from: NSNumber(value: btc))!
        if (btc < 1 && btc > 0) {
            result = "0" + result
        } else if (btc < 0 && btc > -1) {
            result = "-0" + String(result.dropFirst())
        } else if ( btc == 0) {
            result = "0"
        }
        return result
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
