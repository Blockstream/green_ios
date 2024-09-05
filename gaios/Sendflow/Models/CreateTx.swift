import Foundation
import gdk
import greenaddress
import core
import BreezSDK
import lightning

struct CreateTx {
    var addressee: Addressee?
    var feeRate: UInt64?
    var subaccount: WalletItem?
    var error: String?
    var privateKey: String?
    var previousTransaction: [String: Any]?
    var anyAmounts: Bool?
    var bolt11: String?
    var lightningType: InputType?
    var assetId: String? {
        get { addressee?.assetId }
        set { addressee?.assetId = newValue }
    }
    var address: String? {
        get { addressee?.address }
        set { if let value = newValue { addressee?.address = value } }
    }
    var bip21: Bool {
        get { addressee?.bip21 ?? false}
        set { addressee?.bip21 = newValue }
    }
    var satoshi: Int64? {
        get { if let satoshi = addressee?.satoshi { return abs(satoshi) }; return nil }
        set { addressee?.satoshi = newValue }
    }
    var sendAll: Bool {
        get { addressee?.isGreedy ?? false }
        set { addressee?.isGreedy = newValue }
    }
    var isLightning: Bool { lightningType != nil }
    var isLiquid: Bool { !isLightning && (assetId != nil && assetId != "btc") }
    var isBitcoin: Bool { !isLightning && (assetId == nil || assetId == "btc") }

    var txType: TxType
    var txAddress: Address?
}
