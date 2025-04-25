import Foundation
import BreezSDK
import lightning

public enum TransactionError: Error {
    case invalid(localizedDescription: String)
    case failure(localizedDescription: String, paymentHash: String)
}

public enum TxType: Codable {
    case transaction
    case sweep
    case bumpFee
    case bolt11
    case lnurl
    case redepositExpiredUtxos
    case psbt
}

public typealias Metadata = [[String]]
extension Metadata {
    public var plain: String? { self.filter { $0.first == "text/plain" }.compactMap { $0.last }.first }
    public var desc: String? { self.filter { $0.first == "text/long-desc" }.compactMap { $0.last }.first }
    public var image: String? { self.filter { $0.first == "image/png;base64" }.compactMap { $0.last }.first }
}

public struct Bip21Params: Codable {
    enum CodingKeys: String, CodingKey {
        case amount
        case assetid
    }
    public var amount: String?
    public var assetid: String?
}

public struct Addressee: Codable {
    enum CodingKeys: String, CodingKey {
        case address
        case satoshi
        case isGreedy = "is_greedy"
        case assetId = "asset_id"
        case hasLockedAmount = "has_locked_amount"
        case minAmount = "min_amount"
        case maxAmount = "max_amount"
        case domain
        case metadata
        case type
        case bip21
        case bip21Params = "bip21-params"
        case subtype
        case userPath = "user_path"
    }
    public var address: String
    public var satoshi: Int64?
    public var isGreedy: Bool?
    public var assetId: String?
    public let hasLockedAmount: Bool?
    public let minAmount: UInt64?
    public let maxAmount: UInt64?
    public let domain: String?
    public let metadata: Metadata?
    public let type: TxType?
    public var bip21: Bool?
    public let bip21Params: Bip21Params?
    public let subtype: UInt32?
    public let userPath: [UInt32]?

    public static func from(address: String, satoshi: Int64?, assetId: String?, isGreedy: Bool = false, bip21: Bool = false) -> Addressee {
        return Addressee(address: address,
                         satoshi: satoshi,
                         isGreedy: isGreedy,
                         assetId: assetId,
                         hasLockedAmount: nil,
                         minAmount: nil,
                         maxAmount: nil,
                         domain: nil,
                         metadata: nil,
                         type: .transaction,
                         bip21: bip21,
                         bip21Params: nil,
                         subtype: nil,
                         userPath: nil
        )
    }

    public static func fromLnInvoice(_ invoice: LnInvoice, fallbackAmount: UInt64) -> Addressee {
        return Addressee(address: invoice.bolt11,
                         satoshi: -Int64(invoice.amountSatoshi ?? fallbackAmount),
                         assetId: nil,
                         hasLockedAmount: invoice.amountMsat != nil,
                         minAmount: nil,
                         maxAmount: nil,
                         domain: nil,
                         metadata: nil,
                         type: .bolt11,
                         bip21: false,
                         bip21Params: nil,
                         subtype: nil,
                         userPath: nil)
    }

    public static func fromRequestData(_ requestData: LnUrlPayRequestData, input: String, satoshi: UInt64?) -> Addressee {
        return Addressee(
            address: input,
            satoshi: satoshi == nil ? nil : -Int64((requestData.sendableSatoshi(userSatoshi: satoshi) ?? 0)),
            assetId: nil,
            hasLockedAmount: requestData.isAmountLocked,
            minAmount: requestData.minSendableSatoshi,
            maxAmount: requestData.maxSendableSatoshi,
            domain: requestData.domain,
            metadata: requestData.metadata,
            type: .lnurl,
            bip21: false,
            bip21Params: nil,
            subtype: nil,
            userPath: nil)
    }
}

public struct TransactionInputOutput: Codable {
    enum CodingKeys: String, CodingKey {
        case address
        case domain
        case assetId = "asset_id"
        case isChange = "is_change"
        case satoshi
        case amountBlinder = "amountblinder"
        case assetBlinder = "assetblinder"
        case ptIdx = "pt_idx"
        case isRelevant = "is_relevant"
        
    }
    public let address: String?
    public let domain: String?
    public let assetId: String?
    public let isChange: Bool?
    public let satoshi: Int64
    public let amountBlinder: String?
    public let assetBlinder: String?
    public let ptIdx: Int64?
    public let isRelevant: Bool?

    public init(address: String? = nil, domain: String? = nil, assetId: String? = nil, isChange: Bool? = nil, satoshi: Int64, amountBlinder: String? = nil, assetBlinder: String? = nil, ptIdx: Int64? = nil, isRelevant: Bool? = true) {
        self.address = address
        self.domain = domain
        self.assetId = assetId
        self.isChange = isChange
        self.satoshi = satoshi
        self.amountBlinder = amountBlinder
        self.assetBlinder = assetBlinder
        self.ptIdx = ptIdx
        self.isRelevant = isRelevant
    }

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

    public func hasBlindingData() -> Bool {
        return assetId != "" && satoshi != 0 && amountBlinder != "" && assetBlinder != ""
    }

    public func txoBlindingString() -> String? {
        if !hasBlindingData() {
            return nil
        }
        return String(format: "%lu,%@,%@,%@", satoshi, assetId ?? "", amountBlinder ?? "", assetBlinder ?? "")
    }

    public func txoBlindingData(isUnspent: Bool) -> TxoBlindingData {
        return TxoBlindingData.init(vin: !isUnspent ? ptIdx : nil,
                                    vout: isUnspent ? ptIdx : nil,
                                    asset_id: assetId,
                                    assetblinder: assetBlinder,
                                    satoshi: satoshi,
                                    amountblinder: amountBlinder)
    }
}

public enum TransactionType: String, Codable {
    case incoming
    case outgoing
    case redeposit
    case mixed
}

public struct Transaction: Comparable {
    public var details: [String: Any]
    public var subaccount: Int?

    private func get<T>(_ key: String) -> T? {
        return details[key] as? T
    }

    public init(_ details: [String: Any], subaccount: Int? = nil) {
        self.details = details
        self.subaccount = subaccount
    }

    public var addressees: [Addressee] {
        get { (get("addressees") ?? []).compactMap { Addressee.from($0) as? Addressee }}
        set { details["addressees"] = newValue.map { $0.toDict() }}
    }

    public var transaction: String? {
        get { return get("transaction") }
    }

    public var blockHeight: UInt32 {
        get { return get("block_height") ?? 0 }
        set { details["block_height"] = newValue }
    }

    public var privateKey: String? {
        get { return get("private_key") }
        set { details["private_key"] = newValue }
    }

    public var canRBF: Bool {
        get { return get("can_rbf") ?? false }
        set { details["can_rbf"] = newValue }
    }

    public var createdAtTs: Int64 {
        get { return get("created_at_ts") ?? 0 }
        set { details["created_at_ts"] = newValue }
    }

    public var error: String? {
        get {
            if let error: String = get("error"), !error.isEmpty {
                return error
            }
            return nil
        }
        set { details["error"] = newValue }
    }

    public var fee: UInt64? {
        get { if get("fee") == 0 { return nil } else { return get("fee") } }
        set { details["fee"] = newValue }
    }

    public var feeRate: UInt64 {
        get { return get("fee_rate" ) ?? 0 }
        set { details["fee_rate"] = newValue }
    }

    public var hash: String? {
        get { return get("txhash") }
        set { details["txhash"] = newValue }
    }

    public var isSweep: Bool {
        get { privateKey != nil }
    }

    public var memo: String? {
        get { return get("memo") }
        set { details["memo"] = newValue }
    }

    public var isLiquid: Bool {
        amounts["btc"] == nil
    }

    public var sessionSubaccount: UInt32 {
        get { get("subaccount") as UInt32? ?? 0 }
        set { details["subaccount"] = newValue }
    }

    public var amounts: [String: Int64] {
        get { get("satoshi") as [String: Int64]? ?? [:] }
        set { details["satoshi"] = newValue }
    }

    public var size: UInt64 {
        get { return get("transaction_vsize") ?? 0 }
        set { details["transaction_vsize"] = newValue }
    }

    public var type: TransactionType {
        get { TransactionType(rawValue: get("type") ?? "") ?? .outgoing }
        set { details["type"] = newValue.rawValue }
    }

    public var previousTransaction: [String: Any]? {
        get { get("previous_transaction") }
        set { details["previous_transaction"] = newValue }
    }

    public var anyAmouts: Bool {
        get { get("any_amounts") ?? false }
        set { details["any_amounts"] = newValue }
    }

    // tx outputs in create transaction
    public var transactionOutputs: [TransactionInputOutput]? {
        get {
            let params: [[String: Any]]? = get("transaction_outputs")
            return params?.compactMap { TransactionInputOutput.from($0) as? TransactionInputOutput }
        }
        set { details["transaction_outputs"] = newValue?.map { $0.toDict() } }
    }

    // tx inputs in create transaction
    public var transactionInputs: [TransactionInputOutput]? {
        get {
            let params: [[String: Any]]? = get("transaction_inputs")
            return params?.compactMap { TransactionInputOutput.from($0) as? TransactionInputOutput }
        }
        set { details["transaction_inputs"] = newValue?.map { $0.toDict() } }
    }

    // tx utxo strategy
    public var utxoStrategy: String? {
        get { return get("utxo_strategy") }
        set { details["utxo_strategy"] = newValue }
    }
    // tx utxos
    public var utxos: [String: Any]? {
        get { return get("utxos") }
        set { details["utxos"] = newValue }
    }

    // tx outputs in get transaction
    public var outputs: [TransactionInputOutput]? {
        get {
            let params: [[String: Any]]? = get("outputs")
            return params?.compactMap { TransactionInputOutput.from($0) as? TransactionInputOutput }
        }
        set { details["outputs"] = newValue?.map { $0.toDict() } }
    }

    // tx inputs in get transaction
    public var inputs: [TransactionInputOutput]? {
        get {
            let params: [[String: Any]]? = get("inputs")
            return params?.compactMap { TransactionInputOutput.from($0) as? TransactionInputOutput }
        }
        set { details["inputs"] = newValue?.map { $0.toDict() } }
    }

    public var spvVerified: String? {
        get { return get("spv_verified") }
        set { details["spv_verified"] = newValue }
    }

    public var message: String? {
        get { return get("message") }
        set { details["message"] = newValue }
    }

    public var plaintext: (String, String)? {
        get { return get("plaintext") }
        set { details["plaintext"] = newValue }
    }

    public var url: (String, String)? {
        get { return get("url") }
        set { details["url"] = newValue }
    }

    public var paymentHash: String? {
        get { return get("paymentHash") }
        set { details["paymentHash"] = newValue }
    }

    public var destinationPubkey: String? {
        get { return get("destinationPubkey") }
        set { details["destinationPubkey"] = newValue }
    }

    public var paymentPreimage: String? {
        get { return get("paymentPreimage") }
        set { details["paymentPreimage"] = newValue }
    }

    public var invoice: String? {
        get { return get("invoice") }
        set { details["invoice"] = newValue }
    }

    public var closingTxid: String? {
        get { return get("closingTxid") }
        set { details["closingTxid"] = newValue }
    }
    public var fundingTxid: String? {
        get { return get("fundingTxid") }
        set { details["fundingTxid"] = newValue }
    }

    public var isPendingCloseChannel: Bool? {
        get { return get("isPendingCloseChannel") }
        set { details["isPendingCloseChannel"] = newValue }
    }

    public var isLightningSwap: Bool? {
        get { return get("isLightningSwap") }
        set { details["isLightningSwap"] = newValue }
    }

    public var isInProgressSwap: Bool? {
        get { return get("isInProgressSwap") }
        set { details["isInProgressSwap"] = newValue }
    }

    public var isRefundableSwap: Bool? {
        get { return get("isRefundableSwap") }
        set { details["isRefundableSwap"] = newValue }
    }

    public var txType: TxType {
        if privateKey != nil {
            return .sweep
        } else if previousTransaction != nil {
            return .bumpFee
        } else {
            return addressees.first?.type ?? .transaction
        }
    }

    public var isBlinded: Bool {
        get { get("is_blinded") ?? false }
    }

    public func date(dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(Double(createdAtTs / 1000000)))
        return DateFormatter.localizedString(from: date, dateStyle: dateStyle, timeStyle: timeStyle)
    }

    public func blindingData() -> BlindingData {
        let inputs = self.inputs?
            .filter { $0.hasBlindingData() }
            .compactMap { $0.txoBlindingData(isUnspent: false) }
        let outputs = self.outputs?
            .filter { $0.hasBlindingData() }
            .compactMap { $0.txoBlindingData(isUnspent: true) }
        return BlindingData(version: 0,
                            txid: hash ?? "",
                            type: type,
                            inputs: inputs ?? [],
                            outputs: outputs ?? [])
    }

    public func blindingUrlString(address: String? = nil) -> String {
        var blindingUrlString = [String]()
        blindingUrlString += inputs?
            .filter { address == nil || address == $0.address }
            .compactMap { $0.txoBlindingString() } ?? []
        blindingUrlString += outputs?
            .filter { address == nil || address == $0.address }
            .compactMap { $0.txoBlindingString() } ?? []
        blindingUrlString += transactionInputs?
            .filter { address == nil || address == $0.address }
            .compactMap { $0.txoBlindingString() } ?? []
        blindingUrlString += transactionOutputs?
            .filter { address == nil || address == $0.address }
            .compactMap { $0.txoBlindingString() } ?? []
        return blindingUrlString.isEmpty ? "" : "#blinded=" + blindingUrlString.joined(separator: ",")
    }

    public static func == (lhs: Transaction, rhs: Transaction) -> Bool {
        (lhs.details as NSDictionary).isEqual(to: rhs.details)
    }

    public static func < (lhs: Transaction, rhs: Transaction) -> Bool {
        if lhs.createdAtTs == rhs.createdAtTs {
            if lhs.blockHeight == rhs.blockHeight {
                return lhs.type == .outgoing && rhs.type == .incoming
            }
            return lhs.blockHeight < rhs.blockHeight
        }
        return lhs.createdAtTs < rhs.createdAtTs
    }
}

public struct TxoBlindingData: Codable {
    let vin: Int64?
    let vout: Int64?
    let asset_id: String?
    let assetblinder: String?
    let satoshi: Int64
    let amountblinder: String?
}

public struct BlindingData: Codable {
    let version: Int
    let txid: String
    let type: TransactionType
    let inputs: [TxoBlindingData]
    let outputs: [TxoBlindingData]
}
