//
//  String+random.swift
//  gaios
//
//  Created by Strahinja Markovic on 6/19/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation

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
        let btc = satoshi / 100000000
        let result: String = String(format: "%g BTC", btc)
        return result
    }
}
