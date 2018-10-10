//
//  bip21Helper.swift
//  gaios
//
//  Created by Strahinja Markovic on 8/13/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
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
