import Foundation

struct TxChangeOutput: Codable {
    enum CodingKeys: String, CodingKey {
        case path = "path"
        case recoveryxpub = "recovery_xpub"
        case csvBlocks = "csv_blocks"
        case variant
    }
    let path: [Int]
    let recoveryxpub: String?
    let csvBlocks: UInt32
    let variant: String?
}
