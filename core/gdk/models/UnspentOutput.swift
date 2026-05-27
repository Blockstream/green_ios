import Foundation

public struct UnspentOutput: Codable {
    enum CodingKeys: String, CodingKey {
        case subaccount
        case pointer
        case blockHeight = "block_height"
        case addressType = "address_type"
        case prevoutScript = "prevout_script"
        case ptIdx = "pt_idx"
        case satoshi
        case subtype
        case txhash
        case userStatus = "user_status"
        case expiryHeight = "expiry_height"
        case assetId = "asset_id"
        case isConfidential = "is_confidential"
        case amountblinder
        case assetTag = "asset_tag"
        case assetblinder
        case commitment
        case isBlinded = "is_blinded"
        case isInternal = "is_internal"
        case nonceCommitment = "nonce_commitment"
        case publicKey = "public_key"
        case userPath = "user_path"
        case script
    }
    public let subaccount: UInt32
    public let pointer: UInt32
    public let blockHeight: UInt64?
    public let addressType: String?
    public let prevoutScript: String?
    public let ptIdx: UInt32?
    public let satoshi: Int64?
    public let subtype: UInt64?
    public let txhash: String?
    public let userStatus: UInt8?
    public let expiryHeight: UInt64?
    public let assetId: String?
    public let isConfidential: Bool?
    public let amountblinder: String?
    public let assetTag: String?
    public let assetblinder: String?
    public let commitment: String?
    public let isBlinded: Bool?
    public let isInternal: Bool?
    public let nonceCommitment: String?
    public let publicKey: String?
    public let userPath: [UInt32]?
    public let script: String?

    public var isUnconfirmed: Bool {
        return (blockHeight ?? 0) == 0
    }

    public var isLocked: Bool {
        return (userStatus ?? 0) == 1
    }

    public func isDust(isLiquid: Bool) -> Bool {
        guard !isLiquid else { return false }
        return (satoshi ?? 0) < 1092
    }
    
    public func urlForTx(explorerUrl: String?) -> URL? {
        guard let explorerUrl, let txhash, !txhash.isEmpty else { return nil }
        return URL(string: "\(explorerUrl)\(txhash)")
    }
}
