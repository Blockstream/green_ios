import Foundation

public struct Balance: Codable {

    enum CodingKeys: String, CodingKey {
        case bits
        case btc
        case fiat
        case fiatCurrency = "fiat_currency"
        case fiatRate = "fiat_rate"
        case mbtc
        case satoshi
        case ubtc
        case sats
        case assetInfo = "asset_info"
        case asset
        case assetId = "asset_id"
        case assetValue = "asset_value"
    }

    public var bits: String?
    public var btc: String?
    public let fiat: String?
    public let fiatCurrency: String?
    public let fiatRate: String?
    public var mbtc: String?
    public let satoshi: Int64?
    public var ubtc: String?
    public var sats: String?
    public var assetInfo: AssetInfo?
    public var asset: [String: String]?
    public var assetId: String?
    public var assetValue: String?

    public init(bits: String? = nil, btc: String? = nil, fiat: String? = nil, fiatCurrency: String? = nil, fiatRate: String? = nil, mbtc: String? = nil, satoshi: Int64? = nil, ubtc: String? = nil, sats: String? = nil, assetInfo: AssetInfo? = nil, asset: [String : String]? = nil, assetId: String? = nil, assetValue: String? = nil) {
        self.bits = bits
        self.btc = btc
        self.fiat = fiat
        self.fiatCurrency = fiatCurrency
        self.fiatRate = fiatRate
        self.mbtc = mbtc
        self.satoshi = satoshi
        self.ubtc = ubtc
        self.sats = sats
        self.assetInfo = assetInfo
        self.asset = asset
        self.assetId = assetId
        self.assetValue = assetValue
    }
    func toDict() -> [String: Any]? {
        var obj = self
        if let assetId = obj.assetId, let assetValue = obj.assetValue {
            obj.asset?[assetId] = assetValue
        }
        if let data = try? JSONEncoder().encode(obj) {
            return try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
        }
        return nil
    }
    static func from(_ dict: [AnyHashable: Any]) -> Balance? {
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let json = try? JSONDecoder().decode(self, from: data) {
            return json
        }
        return nil
    }
}
