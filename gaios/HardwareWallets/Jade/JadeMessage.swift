import Foundation
import SwiftCBOR

struct JadeSignTx: Codable {
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

struct JadeGetReceiveMultisigAddress: Codable {
    enum CodingKeys: String, CodingKey {
        case network = "network"
        case pointer = "pointer"
        case subaccount = "subaccount"
        case branch = "branch"
        case recoveryXpub = "recovery_xpub"
        case csvBlocks = "csv_blocks"
    }
    let network: String
    let pointer: UInt32
    let subaccount: UInt32
    let branch: UInt32
    let recoveryXpub: String?
    let csvBlocks: UInt32?
}

struct JadeGetReceiveSinglesigAddress: Codable {
    enum CodingKeys: String, CodingKey {
        case network
        case path
        case variant
    }
    let network: String
    let path: [UInt32]
    let variant: String
}

struct JadeGetXpub: Codable {
    enum CodingKeys: String, CodingKey {
        case network
        case path
    }
    let network: String
    let path: [UInt32]
}

struct JadeSignMessage: Codable {
    enum CodingKeys: String, CodingKey {
        case message
        case path
        case aeHostCommitment = "ae_host_commitment"
    }
    let message: String
    let path: [UInt32]
    let aeHostCommitment: Data?
}

struct JadeGetSignature: Codable {
    enum CodingKeys: String, CodingKey {
        case aeHostEntropy = "ae_host_entropy"
    }
    let aeHostEntropy: Data
}

struct JadeAddEntropy: Codable {
    enum CodingKeys: String, CodingKey {
        case entropy
    }
    let entropy: Data
}

struct JadeEmpty: Codable {
}

struct JadeVersionInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case jadeVersion = "JADE_VERSION"
        case jadeOtaMaxChunk = "JADE_OTA_MAX_CHUNK"
        case jadeConfig = "JADE_CONFIG"
        case boardType = "BOARD_TYPE"
        case jadeState = "JADE_STATE"
        case jadeNetworks = "JADE_NETWORKS"
        case jadeFeatures = "JADE_FEATURES"
        case jadeHasPin = "JADE_HAS_PIN"
    }
    let jadeVersion: String
    let jadeOtaMaxChunk: Int
    let jadeConfig: String
    let boardType: String
    let jadeState: String
    let jadeNetworks: String
    let jadeFeatures: String
    let jadeHasPin: Bool
}

struct JadeRequest<T: Codable>: Decodable, Encodable {
    let id: String
    let method: String
    let params: T?

    private enum CodingKeys: String, CodingKey {
        case id
        case method
        case params
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        method = try container.decode(String.self, forKey: .method)
        params = try T(from: decoder)
    }

    init(id: String? = nil, method: String, params: T? = nil) {
        self.id = id ?? "\(100000 + Int.random(in: 0 ..< 899999))"
        self.method = method
        self.params = params
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(method, forKey: .method)
        if params != nil {
            try container.encode(params, forKey: .params)
        }
    }

    var encoded: Data? {
        try? CodableCBOREncoder().encode(self)
    }
}

struct JadeResponseError: Codable {
    let code: Int
    let message: String
    let data: Data? = nil

    private enum CodingKeys: String, CodingKey {
        case code
        case message
        case data
    }
}

struct JadeResponse<T: Codable>: Decodable, Encodable {
    let id: String
    let error: JadeResponseError?
    let result: T?

    private enum CodingKeys: String, CodingKey {
        case id
        case error
        case result
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        error = try container.decode(JadeResponseError.self, forKey: .error)
        result = try T(from: decoder)
    }

    init(id: String, error: JadeResponseError?, result: T? = nil) {
        self.id = id
        self.error = error
        self.result = result
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        if error != nil {
            try container.encode(error, forKey: .error)
        }
        if result != nil {
            try container.encode(result, forKey: .result)
        }
    }

    var encoded: Data? {
        try? CodableCBOREncoder().encode(self)
    }
}
