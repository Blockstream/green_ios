import Foundation

public struct TxOutputUnblindedData: Codable {
    enum CodingKeys: String, CodingKey {
        case vout
        case assetId = "asset_id"
        case satoshi
        case assetblinder
        case amountblinder
    }
    let vout: Int64?
    let assetId: String?
    let satoshi: Int64
    let assetblinder: String?
    let amountblinder: String?
}
