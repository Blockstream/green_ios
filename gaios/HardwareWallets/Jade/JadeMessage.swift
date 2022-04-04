import Foundation
import SwiftCBOR

struct SignTx: Codable {
    enum CodingKeys: String, CodingKey {
        case change = "change"
        case network = "network"
        case numInputs = "num_inputs"
        case trustedCommitments = "trusted_commitments"
        case aeHostCommitment = "ae_host_commitment"
        case txn = "txn"
    }
    let change: [TxChangeOutput?]
    let network: String
    let numInputs: Int
    let trustedCommitments: [Commitment?]?
    let aeHostCommitment: Bool
    let txn: Data
}

struct JadePackage<T: Codable>: Decodable, Encodable {
    let id: Int
    let method: String
    let params: T?

    private enum CodingKeys: String, CodingKey {
        case id
        case method
        case params
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        method = try container.decode(String.self, forKey: .method)
        params = try T(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(method, forKey: .method)
        if params != nil {
            try container.encode(params, forKey: .params)
        }
    }
}
