import Foundation

public struct CountlyEnrichedAsset: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case amp
        case weight
    }

    public let id: String
    public let amp: Bool?
    public let weight: Int?
}
