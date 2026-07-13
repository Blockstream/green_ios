import Foundation

public struct TxInputUnblindedData: Codable {
    enum CodingKeys: String, CodingKey {
        case vin
        case assetId = "asset_id"
        case satoshi
        case assetblinder
        case amountblinder
    }
    let vin: Int64?
    let assetId: String?
    let satoshi: Int64
    let assetblinder: String?
    let amountblinder: String?
}
