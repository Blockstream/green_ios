import Foundation
import UIKit

public struct AssentEntity: Codable {
    public let domain: String
}

public struct SortingAsset {
    public let tag: String
    public let info: AssetInfo?
    public let hasImage: Bool
    public let value: Int64
}

public struct AssetInfo: Codable, Equatable {

    enum CodingKeys: String, CodingKey {
        case assetId = "asset_id"
        case name
        case precision
        case ticker
        case entity
        case amp
        case weight
    }

    public var assetId: String
    public var name: String?
    public var precision: UInt8?
    public var ticker: String?
    public var entity: AssentEntity?
    public var amp: Bool?
    public var weight: Int?

    public init(assetId: String, name: String?, precision: UInt8, ticker: String?) {
        self.assetId = assetId
        self.name = name
        self.precision = precision
        self.ticker = ticker
    }

    public func encode() -> [String: Any]? {
        return try? JSONSerialization.jsonObject(with: JSONEncoder().encode(self), options: .allowFragments) as? [String: Any]
    }

    public static func == (lhs: AssetInfo, rhs: AssetInfo) -> Bool {
        lhs.assetId == rhs.assetId
    }

    public var isLightning: Bool { assetId == AssetInfo.lightningId }
    public var isBitcoin: Bool { assetId == AssetInfo.btcId }
    public var isLiquid: Bool { ![AssetInfo.btcId, AssetInfo.testId, AssetInfo.lightningId].contains(assetId) }

    // Default asset id
    public static var btcId = "btc"
    public static var testId = "btc"
    public static var lbtcId = NetworkId.electrumLiquid.gdkNetwork.getFeeAsset()
    public static var ltestId = NetworkId.electrumTestnetLiquid.gdkNetwork.getFeeAsset()
    public static var lightningId = "lightning"
    public static var baseIds = [btcId, testId, lbtcId, ltestId, lightningId]

    public static let all = [btc, test, lbtc, ltest, lightning]

    // Default asset info
    public static var btc: AssetInfo {
        let denom = WalletManager.current?.prominentNetworkBackend?.settings?.denomination ?? .BTC
        return AssetInfo(assetId: btcId,
                         name: "Bitcoin",
                         precision: denom.digits,
                         ticker: DenominationType.denominationsBTC[denom])
    }

    public static var test: AssetInfo {
        let denom = WalletManager.current?.prominentNetworkBackend?.settings?.denomination ?? .BTC
        return AssetInfo(assetId: testId,
                         name: "Testnet Bitcoin",
                         precision: denom.digits,
                         ticker: DenominationType.denominationsTEST[denom])
    }

    public static var lbtc: AssetInfo {
        let denom = WalletManager.current?.prominentNetworkBackend?.settings?.denomination ?? .BTC
        return AssetInfo(assetId: lbtcId,
                         name: "Liquid Bitcoin",
                         precision: denom.digits,
                         ticker: DenominationType.denominationsLBTC[denom])
    }

    public static var ltest: AssetInfo {
        let denom = WalletManager.current?.prominentNetworkBackend?.settings?.denomination ?? .BTC
        return AssetInfo(assetId: ltestId,
                         name: "Testnet Liquid Bitcoin",
                         precision: denom.digits,
                         ticker: DenominationType.denominationsLTEST[denom])
    }
    public static var lightning: AssetInfo {
        let denom = WalletManager.current?.prominentNetworkBackend?.settings?.denomination ?? .BTC
        return AssetInfo(assetId: lightningId,
                         name: "Lightning Bitcoin",
                         precision: denom.digits,
                         ticker: DenominationType.denominationsBTC[denom])
    }
}
