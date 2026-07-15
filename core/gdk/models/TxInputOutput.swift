import Foundation

public struct TxInputOutput: Codable {
    
    enum CodingKeys: String, CodingKey {
        case address
        case addressee
        case addressType = "address_type"
        case assetId = "asset_id"
        case assetTag = "asset_tag"
        case isChange = "is_change"
        case isInternal = "is_internal"
        case satoshi
        case amountBlinder = "amountblinder"
        case assetBlinder = "assetblinder"
        case ptIdx = "pt_idx"
        case isRelevant = "is_relevant"
        case isOutput = "is_output"
        case isSpent = "is_spent"
        case pointer
        case subaccount
        case subtype
        case commitment
        case isBlinded = "is_blinded"
        case nonceCommitment = "nonce_commitment"
        case previdx
        case prevtxhash
        case script
        case blindingKey = "blinding_key"
        case isConfidential = "is_confidential"
        case unconfidentialAddress = "unconfidential_address"
        case txHash = "txhash"
        case userPath = "user_path"
        case ephPublicKey = "eph_public_key"
    }
    // Bitcoin & Liquid
    public let address: String?
    public let addressee: String?
    public let addressType: String?
    public let isChange: Bool?
    public let satoshi: Int64?
    public let ptIdx: Int64?
    public let isRelevant: Bool?
    public let isInternal: Bool?
    public let isOutput: Bool?
    public let isSpent: Bool?
    public let pointer: Int?
    public let subaccount: Int?
    public let subtype: Int?
    // Liquid Input & Output
    public let assetId: String?
    public let assetTag: String?
    public let amountBlinder: String?
    public let assetBlinder: String?
    public let commitment: String?
    public let isBlinded: Bool?
    public let nonceCommitment: String?
    public let previdx: Int?
    public let prevtxhash: String?
    public let script: String?
    // Liquid Output
    public let blindingKey: String?
    public let isConfidential: Bool?
    public let unconfidentialAddress: Bool?
    // Others
    public let txHash: String?
    public let userPath: [UInt32]?
    public let ephPublicKey: String? // our ephemeral public key for [un]blinding

    public init(address: String? = nil, addressee: String? = nil, addressType: String? = nil, isChange: Bool? = nil, satoshi: Int64? = nil, ptIdx: Int64? = nil, isRelevant: Bool? = nil, isInternal: Bool? = nil, isOutput: Bool? = nil, isSpent: Bool? = nil, pointer: Int? = nil, subaccount: Int? = nil, subtype: Int? = nil, assetId: String? = nil, assetTag: String? = nil, amountBlinder: String? = nil, assetBlinder: String? = nil, commitment: String? = nil, isBlinded: Bool? = nil, nonceCommitment: String? = nil, previdx: Int? = nil, prevtxhash: String? = nil, script: String? = nil, blindingKey: String? = nil, isConfidential: Bool? = nil, unconfidentialAddress: Bool? = nil, txHash: String? = nil, userPath: [UInt32]? = nil, ephPublicKey: String? = nil) {
        self.address = address
        self.addressee = addressee
        self.addressType = addressType
        self.isChange = isChange
        self.satoshi = satoshi
        self.ptIdx = ptIdx
        self.isRelevant = isRelevant
        self.isInternal = isInternal
        self.isOutput = isOutput
        self.isSpent = isSpent
        self.pointer = pointer
        self.subaccount = subaccount
        self.subtype = subtype
        self.assetId = assetId
        self.assetTag = assetTag
        self.amountBlinder = amountBlinder
        self.assetBlinder = assetBlinder
        self.commitment = commitment
        self.isBlinded = isBlinded
        self.nonceCommitment = nonceCommitment
        self.previdx = previdx
        self.prevtxhash = prevtxhash
        self.script = script
        self.blindingKey = blindingKey
        self.isConfidential = isConfidential
        self.unconfidentialAddress = unconfidentialAddress
        self.txHash = txHash
        self.userPath = userPath
        self.ephPublicKey = ephPublicKey
    }
    /*
     public static func fromLnInvoice(_ invoice: LnInvoice, fallbackAmount: Int64?) -> TransactionInputOutput {
     return TransactionInputOutput(
     address: invoice.bolt11,
     domain: nil,
     assetId: nil,
     isChange: false,
     satoshi: -Int64((invoice.amountSatoshi ?? UInt64(fallbackAmount ?? 0))),
     amountBlinder: nil,
     assetBlinder: nil,
     ptIdx: nil,
     isRelevant: nil
     )
     }
     public static func fromLnUrlPay(_ requestData: LnUrlPayRequestData, input: String, satoshi: Int64?) -> TransactionInputOutput {
     return TransactionInputOutput(
     address: input,
     domain: requestData.domain,
     assetId: nil,
     isChange: false,
     satoshi: -Int64(requestData.sendableSatoshi(userSatoshi: UInt64(satoshi ?? 0)) ?? 0),
     amountBlinder: nil,
     assetBlinder: nil,
     ptIdx: nil,
     isRelevant: nil
     )
     }
     */
    func hasUnblindingData() -> Bool {
        return assetId != nil &&
        satoshi != nil
        &&
        assetBlinder != nil &&
        amountBlinder != nil &&
        assetId.isNotEmpty  &&
        amountBlinder
            .isNotEmpty &&
        assetBlinder
            .isNotEmpty
    }

    public func getUnblindedString() -> String? {
        if !hasUnblindingData() {
            return nil
        }
        return String(format: "%lu,%@,%@,%@", satoshi ?? "", assetId ?? "", amountBlinder ?? "", assetBlinder ?? "")
    }
    public func isSegwit() -> Bool {
        ["csv", "p2wsh", "p2wpkh", "p2sh-p2wpkh"].contains(addressType)
    }

    public func getAbfs() -> Data? {
        assetBlinder?.hexToDataReversed
    }

    public func getVbfs() -> Data? {
        amountBlinder?.hexToDataReversed
    }

    public func getTxid() -> Data? {
        txHash?.hexToDataReversed
    }

    public func getPublicKeyData() -> Data? {
        return blindingKey.hexToData
    }

    public func getRevertedAssetIdData() -> Data? {
        return assetId?.hexToDataReversed
    }

    public func getCommitmentData() -> Data? {
        return commitment.hexToData
    }
}
