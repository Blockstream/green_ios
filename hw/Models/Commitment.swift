import Foundation

struct Commitment: Codable {
    enum CodingKeys: String, CodingKey {
        case assetId = "asset_id"
        case value = "value"
        case abf = "abf"
        case vbf = "vbf"
        case blindingKey = "blinding_key"
    }
    let assetId: Data?
    let value: UInt64?
    let abf: Data?
    let vbf: Data?
    var blindingKey: Data?
}
