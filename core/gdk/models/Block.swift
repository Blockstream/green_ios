import Foundation

public struct Block: Codable {

    enum CodingKeys: String, CodingKey {
        case hash = "block_hash"
        case height = "block_height"
        case timestamp = "initial_timestamp"
    }
    public let hash: String?
    public let height: UInt32
    public let timestamp: Int64?
}
