import Foundation
import UIKit
import gdk
import lightning

struct ReceiveAddressCellModel {
    var text: String?
    var isBip21: Bool
    var type: ReceiveType

    var satoshi: Int64?
    var maxLimit: UInt64?
    var inputDenomination: DenominationType
    let isLightning: Bool

    var btc: String? {
        if let satoshi = satoshi {
            if let res = Balance.fromSatoshi(satoshi, assetId: AssetInfo.btcId)?.toDenom(inputDenomination) {
                return "\(res.0) \(res.1)"
            }
        }
        return ""
    }

    var maxSendable: String? {
        if let maxLimit = maxLimit {
            if let res = Balance.fromSatoshi(UInt64(maxLimit), assetId: AssetInfo.btcId)?.toDenom(inputDenomination) {
                return "\(res.0) \(res.1)"
            }
        }
        return nil
    }
}
