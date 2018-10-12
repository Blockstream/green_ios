//
//  bip21Helper.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/15/18.
//  Copyright © 2018 Blockstream inc. All rights reserved.
//

import Foundation

class bip21Helper {

    static func btcURIforAmnount(address: String, amount: Double) ->String {
        let result = String(format: "bitcoin:%@?amount=%f", address, amount)
        return result
    }

    static func btcURIforAddress(address: String) ->String {
        let result = String(format: "bitcoin:%@", address)
        return result
    }
}
