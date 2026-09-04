import Foundation
import SwiftCBOR

public struct JadeSignTx: Codable {
    enum CodingKeys: String, CodingKey {
        case change = "change"
        case network = "network"
        case numInputs = "num_inputs"
        case trustedCommitments = "trusted_commitments"
        case useAeProtocol = "use_ae_signatures"
        case txn = "txn"
    }
    let change: [TxChangeOutput?]
    let network: String
    let numInputs: Int
    let trustedCommitments: [Commitment?]?
    let useAeProtocol: Bool
    let txn: Data
}

public struct JadeAssetInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case assetId = "asset_id"
        case contract
        case issuancePrevout = "issuance_prevout"
    }

    // Jade hashes the contract in a 768-byte buffer; skip oversized entries instead of
    // failing the whole signing request.
    private static let maxContractJsonSize = 700

    let assetId: String
    let contract: [String: JadeAssetInfoValue]
    let issuancePrevout: JadeAssetInfoPrevout

    init?(_ details: [String: Any]) {
        guard let assetId = details["asset_id"] as? String,
              let contract = details["contract"] as? [String: Any],
              let issuancePrevout = details["issuance_prevout"] as? [String: Any],
              let txid = issuancePrevout["txid"] as? String,
              let vout = (issuancePrevout["vout"] as? NSNumber)?.uint32Value,
              let contractJson = try? JSONSerialization.data(withJSONObject: contract, options: []),
              contractJson.count <= JadeAssetInfo.maxContractJsonSize else {
            return nil
        }
        // Jade asserts the ticker fits its 8-byte buffer; a missing, empty, or overlong
        // ticker would abort the device, so drop the entry (truncating breaks the hash).
        // TODO: remove once fixed in Jade firmware (Blockstream/Jade#313).
        guard let ticker = contract["ticker"] as? String,
              (1...7).contains(ticker.utf8.count) else {
            return nil
        }
        var contractValues = [String: JadeAssetInfoValue]()
        for (key, value) in contract {
            guard let value = JadeAssetInfoValue(value) else { return nil }
            contractValues[key] = value
        }
        self.assetId = assetId
        self.contract = contractValues
        self.issuancePrevout = JadeAssetInfoPrevout(txid: txid, vout: vout)
    }
}

public struct JadeAssetInfoPrevout: Codable {
    let txid: String
    let vout: UInt32
}

public indirect enum JadeAssetInfoValue: Codable {
    case array([JadeAssetInfoValue])
    case boolean(Bool)
    case double(Double)
    case integer(Int64)
    case null
    case object([String: JadeAssetInfoValue])
    case string(String)

    init?(_ value: Any) {
        switch value {
        case is NSNull:
            self = .null
        case let value as String:
            self = .string(value)
        case let value as NSNumber:
            // CFGetTypeID is required: "as? Bool" bridges NSNumber 0 to false and 1 to true.
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                self = .boolean(value.boolValue)
            } else if ["f", "d"].contains(String(cString: value.objCType)) {
                self = .double(value.doubleValue)
            } else {
                self = .integer(value.int64Value)
            }
        case let value as [Any]:
            let values = value.compactMap(JadeAssetInfoValue.init)
            guard values.count == value.count else { return nil }
            self = .array(values)
        case let value as [String: Any]:
            var values = [String: JadeAssetInfoValue]()
            for (key, item) in value {
                guard let item = JadeAssetInfoValue(item) else { return nil }
                values[key] = item
            }
            self = .object(values)
        default:
            return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JadeAssetInfoValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JadeAssetInfoValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .array(let value):
            try container.encode(value)
        case .boolean(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        case .object(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
}

public struct JadeGetReceiveMultisigAddress: Codable {
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

public struct JadeGetReceiveSinglesigAddress: Codable {
    enum CodingKeys: String, CodingKey {
        case network
        case path
        case variant
    }
    let network: String
    let path: [UInt32]
    let variant: String
}

public struct JadeGetXpub: Codable {
    enum CodingKeys: String, CodingKey {
        case network
        case path
    }
    let network: String
    let path: [UInt32]
}

public struct JadeSignMessage: Codable {
    enum CodingKeys: String, CodingKey {
        case message
        case path
        case aeHostCommitment = "ae_host_commitment"
    }
    let message: String
    let path: [UInt32]
    let aeHostCommitment: Data?
}

public struct JadeSignAttestation: Codable {
    enum CodingKeys: String, CodingKey {
        case challenge
    }
    let challenge: Data
    public init(challenge: Data) {
        self.challenge = challenge
    }
}

public struct JadeSignAttestationResult: Codable {
    enum CodingKeys: String, CodingKey {
        case extSignature = "ext_signature"
        case pubkeyPem = "pubkey_pem"
        case signature = "signature"
    }
    public let extSignature: Data
    public let pubkeyPem: String
    public let signature: Data
}

public struct JadeGetSignature: Codable {
    enum CodingKeys: String, CodingKey {
        case aeHostEntropy = "ae_host_entropy"
    }
    let aeHostEntropy: Data
}

public struct JadeAddEntropy: Codable {
    let entropy: Data
}

public struct JadeGetBlindingKey: Codable {
    let script: Data

    init(scriptHex: String) {
        script = scriptHex.hexToData()
    }
}

public struct JadeGetSharedNonce: Codable {
    enum CodingKeys: String, CodingKey {
        case script = "script"
        case theirPubkey = "their_pubkey"
    }
    let script: Data
    let theirPubkey: Data

    init(scriptHex: String, theirPubkeyHex: String) {
        script = scriptHex.hexToData()
        theirPubkey = theirPubkeyHex.hexToData()
    }
}

public struct JadeGetCommitment: Codable {
    enum CodingKeys: String, CodingKey {
        case hashPrevouts = "hash_prevouts"
        case outputIdx = "output_index"
        case assetId = "asset_id"
        case value = "value"
        case vbf = "vbf"
    }
    let hashPrevouts: Data
    let outputIdx: Int
    let assetId: Data
    let value: UInt64
    let vbf: Data?
}

public struct JadeGetMasterBlindingKey: Codable {
    enum CodingKeys: String, CodingKey {
        case onlyIfSilent = "only_if_silent"
    }
    let onlyIfSilent: Bool?
}

public struct JadeGetBlingingFactor: Codable {
    enum CodingKeys: String, CodingKey {
        case hashPrevouts = "hash_prevouts"
        case outputIndex = "output_index"
        case type = "type"
    }
    let hashPrevouts: Data?
    let outputIndex: Int
    let type: String
}

public struct JadeOta: Codable {
    let fwsize: Int
    let cmpsize: Int
    let otachunk: Int
    let cmphash: Data
    let patchsize: Int?
}

public struct JadeAuthRequest: Codable {
    enum CodingKeys: String, CodingKey {
        case network
        case epoch
    }
    let network: String
    public let epoch: UInt32
}

public struct JadeHandshakeCompleteReply: Codable {
    enum CodingKeys: String, CodingKey {
        case hmac = "hmac"
        case encryptedKey = "encrypted_key"
    }
    public let hmac: String
    public let encryptedKey: String
}

public struct JadeHandshakeComplete: Codable {
    enum CodingKeys: String, CodingKey {
        case ske = "ske"
        case cke = "cke"
        case encryptedData = "encrypted_data"
        case hmacEncryptedData =  "hmac_encrypted_data"
    }
    public let ske: String
    public let cke: String
    public let encryptedData: String
    public let hmacEncryptedData: String
}

public struct JadeHttpData: Codable {
    enum CodingKeys: String, CodingKey {
        case data
    }
    public let data: String
}

public struct JadeHandshakeInit: Codable {
    enum CodingKeys: String, CodingKey {
        case sig
        case ske
    }
    public let sig: String
    public let ske: String
}

public struct JadeHttpRequestParams<T: Codable>: Codable {
    enum CodingKeys: String, CodingKey {
        case urls
        case method
        case accept
        case data
    }
    public let urls: [String]
    public let method: String
    public let accept: String
    public let data: T
}

public struct JadeHttpRequest<T: Codable>: Codable {
    enum CodingKeys: String, CodingKey {
        case params = "params"
        case onReply = "on-reply"
    }
    public let params: JadeHttpRequestParams<T>
    public let onReply: String
}

public struct JadeAuthResponse<T: Codable>: Codable {
    enum CodingKeys: String, CodingKey {
        case httpRequest = "http_request"
    }
    public let httpRequest: JadeHttpRequest<T>
}

public struct JadeEmpty: Codable {
}

public struct JadeVersionInfo: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case jadeVersion = "JADE_VERSION"
        case jadeOtaMaxChunk = "JADE_OTA_MAX_CHUNK"
        case jadeConfig = "JADE_CONFIG"
        case boardType = "BOARD_TYPE"
        case jadeState = "JADE_STATE"
        case jadeNetworks = "JADE_NETWORKS"
        case jadeFeatures = "JADE_FEATURES"
        case jadeHasPin = "JADE_HAS_PIN"
        case efusemac = "EFUSEMAC"
    }
    public var jadeVersion: String
    public let jadeOtaMaxChunk: Int
    public let jadeConfig: String
    public let boardType: JadeBoardType
    public let jadeState: String
    public let jadeNetworks: String
    public let jadeFeatures: String
    public let jadeHasPin: Bool
    public let efusemac: String?
}

public struct GetBlindingFactorParams: Codable {
    enum CodingKeys: String, CodingKey {
        case hashPrevouts = "hash_prevouts"
        case outputIndex = "output_index"
        case type
    }
    let hashPrevouts: Data
    let outputIndex: UInt32
    let type: String
}

public var JadeRequestId = Int.random(in: 0 ..< 899999)

public struct JadeRequest<T: Codable>: Decodable, Encodable {
    public let id: String
    public let method: String
    public let params: T?

    private enum CodingKeys: String, CodingKey {
        case id
        case method
        case params
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        method = try container.decode(String.self, forKey: .method)
        params = try container.decodeIfPresent(T.self, forKey: .params)
    }

    public init(id: String? = nil, method: String, params: T? = nil) {
        self.id = id ?? "\(JadeRequestId)"
        JadeRequestId += 1
        self.method = method
        self.params = params
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(method, forKey: .method)
        try container.encodeIfPresent(params, forKey: .params)
    }

    public var encoded: Data? {
        try? CodableCBOREncoder().encode(self)
    }
}

public struct JadeResponseError: Codable {
    public let code: Int
    public let message: String
    public let data: Data?

    private enum CodingKeys: String, CodingKey {
        case code
        case message
        case data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(Int.self, forKey: .code)
        message = try container.decode(String.self, forKey: .message)
        data = try? container.decode(Data.self, forKey: .data)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        try container.encode(message, forKey: .message)
        try container.encodeIfPresent(data, forKey: .data)
    }
}

public struct JadeResponse<T: Codable>: Decodable, Encodable {
    public let id: String
    public let error: JadeResponseError?
    public let result: T?

    private enum CodingKeys: String, CodingKey {
        case id
        case error
        case result
    }

    public init(id: String, error: JadeResponseError?, result: T? = nil) {
        self.id = id
        self.error = error
        self.result = result
    }

    public var encoded: Data? {
        try? CodableCBOREncoder().encode(self)
    }
}

public struct Firmware: Codable {
    enum CodingKeys: String, CodingKey {
        case filename = "filename"
        case version = "version"
        case config = "config"
        case fwsize = "fwsize"
        case fromVersion = "from_version"
        case fromConfig = "from_config"
        case patchSize = "patch_size"
    }
    public let filename: String
    public let version: String
    public let config: String
    public let fwsize: Int
    public let fromVersion: String?
    public let fromConfig: String?
    public let patchSize: Int?

    public func upgradable(_ jadeVersion: String) -> Bool {
        return self.config == "ble" && self.version > jadeVersion &&
        self.fromConfig ?? "ble" == "ble" && self.fromVersion ?? jadeVersion == jadeVersion
    }

    public var isDelta: Bool {
        return patchSize == nil
    }
}

public struct FirmwareVersions: Codable {
    public let full: [Firmware]?
    public let delta: [Firmware]?
}

public struct FirmwareChannels: Codable {
    public let beta: FirmwareVersions?
    public let stable: FirmwareVersions?
    public let previous: FirmwareVersions?
}
