import Foundation
import lightning

public enum TransactionError: Error {
    case invalid(localizedDescription: String, maxPayable: UInt64? = nil)
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
    case lwkSwap
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

    public static func from(address: String, satoshi: Int64?, assetId: String?, isGreedy: Bool = false, bip21: Bool = false, txType: TxType = .transaction) -> Addressee {
        return Addressee(address: address,
                         satoshi: satoshi,
                         isGreedy: isGreedy,
                         assetId: assetId,
                         hasLockedAmount: nil,
                         minAmount: nil,
                         maxAmount: nil,
                         domain: nil,
                         metadata: nil,
                         type: txType,
                         bip21: bip21,
                         bip21Params: nil,
                         subtype: nil,
                         userPath: nil
        )
    }
/*
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
    }*/
}


public enum TransactionType: String, Codable {
    case incoming
    case outgoing
    case redeposit
    case mixed
    case issuance
    case reissuance
    case burn
    case unknown
}

public struct Transaction: Comparable {
    public var details: [String: Any]
    public var accountId: String?

    public var networkIdInjected: NetworkId? {
        guard let network = accountId?.split(separator: ":").first else {
            return nil
        }
        return NetworkId(network: String(network))
    }
    public var accountInjected: Account? {
        guard let networkIdInjected else {
            return nil
        }
        let backend = try? WalletManager.current?.networkBackend(networkIdInjected)
        return backend?.accounts.first { $0.id == accountId }
    }

    mutating func setup(account: Account) {
        self.accountId = account.id
    }

    private func get<T>(_ key: String) -> T? {
        return details[key] as? T
    }

    public init(_ details: [String: Any], accountId: String? = nil) {
        self.details = details
        self.accountId = accountId
    }

    public var addressees: [Addressee] {
        get { (get("addressees") ?? []).compactMap { Addressee.from($0) as? Addressee }}
        set { details["addressees"] = newValue.map { $0.toDict() }}
    }

    public var transaction: String? {
        get { return get("transaction") }
        set { details["transaction"] = newValue }
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
        amounts[AssetInfo.btcId] == nil &&
        amounts[AssetInfo.lightningId] == nil
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
    public var transactionOutputs: [TxInputOutput]? {
        get {
            let params: [[String: Any]]? = get("transaction_outputs")
            return params?.compactMap { TxInputOutput.from($0) as? TxInputOutput }
        }
        set { details["transaction_outputs"] = newValue?.map { $0.toDict() } }
    }

    // tx inputs in create transaction
    public var transactionInputs: [TxInputOutput]? {
        get {
            let params: [[String: Any]]? = get("transaction_inputs")
            return params?.compactMap { TxInputOutput.from($0) as? TxInputOutput }
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
    public var outputs: [TxInputOutput]? {
        get {
            let params: [[String: Any]]? = get("outputs")
            return params?.compactMap { TxInputOutput.from($0) as? TxInputOutput }
        }
        set { details["outputs"] = newValue?.map { $0.toDict() } }
    }

    // tx inputs in get transaction
    public var inputs: [TxInputOutput]? {
        get {
            let params: [[String: Any]]? = get("inputs")
            return params?.compactMap { TxInputOutput.from($0) as? TxInputOutput }
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

    public var isMeldPayment: Bool? {
        get { return get("isMeldPayment") }
        set { details["isMeldPayment"] = newValue }
    }

    public var pset: String? {
        get { return get("pset") }
        set { details["pset"] = newValue }
    }
    public var psbt: String? {
        get { return get("psbt") }
        set { details["psbt"] = newValue }
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
    public var unblindingUrl: String? {
        get {
            return get( "unblindingUrl") ?? unblindingUrlString()
        }
        set { details["unblindingUrl"] = newValue }
    }

    public func date(dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(Double(createdAtTs / 1_000_000)))
        return DateFormatter.localizedString(from: date, dateStyle: dateStyle, timeStyle: timeStyle)
    }

    public func unblindingData() -> TxUnblindedData {
        let unblindedInputs = self.inputs?
            .filter { $0.hasUnblindingData() }
            .compactMap {
                TxInputUnblindedData(
                    vin: $0.ptIdx ?? 0,
                    assetId: $0.assetId ?? "",
                    satoshi: $0.satoshi ?? 0,
                    assetblinder: $0.assetBlinder ?? "",
                    amountblinder: $0.amountBlinder ?? ""
                )
            }
        let unblindedOutputs = self.outputs?
            .filter { $0.hasUnblindingData() }
            .compactMap {
                TxOutputUnblindedData(
                    vout: $0.ptIdx ?? 0,
                    assetId: $0.assetId ?? "",
                    satoshi: $0.satoshi ?? 0,
                    assetblinder: $0.assetBlinder ?? "",
                    amountblinder: $0.amountBlinder ?? ""
                )
            }
        return TxUnblindedData(
            version: 0,
            txid: hash ?? "",
            type: type,
            inputs: unblindedInputs ?? [],
            outputs: unblindedOutputs ?? [])
    }

    public func unblindingUrlString(address: String? = nil) -> String {
        let inputTexts = inputs?.compactMap { $0.getUnblindedString() } ?? []
        let outputTexts = outputs?.compactMap { $0.getUnblindedString() } ?? []
        let blindingUrlString = (inputTexts + outputTexts).joined(separator: ",")
        return "\(networkIdInjected?.gdkNetwork.txExplorerUrl ?? "")\(hash ?? "")#blinded=\(blindingUrlString)"
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

    public var feeAsset: String {
        accountInjected?.gdkNetwork.getFeeAsset() ?? "btc"
    }

    public var amountsWithFee: [String: Int64] {
        var amounts = amounts
        amounts[feeAsset] = (amounts[feeAsset] ?? 0) - Int64(fee ?? 0)
        return amounts
    }
    public func amountsWithFees() -> [String: Int64] {
        if type == .redeposit {
            return [feeAsset: -1 * Int64(fee ?? 0)]
        } else {
            // remove LBTC asset only if fee on outgoing transactions
            if type == .some(.outgoing) || type == .some(.mixed) {
                return amounts.filter({ !($0.key == feeAsset && abs($0.value) == Int64(fee ?? 0)) })
            }
        }
        return amounts
    }

    public var amountsWithoutFees: [String: Int64] {
        if type == .some(.redeposit) {
            return [:]
        } else if isLiquid {
            // remove LBTC asset only if fee on outgoing transactions
            if type == .some(.outgoing) || type == .some(.mixed) {
                return amounts.filter({ !($0.0 == feeAsset && abs($0.1) == Int64(fee ?? 0)) })
            }
        }
        return amounts
    }

    public var isLightning: Bool {
        self.accountInjected?.gdkNetwork.lightning ?? false
    }

    public func isUnconfirmed(block: UInt32) -> Bool {
        if isLightning {
            return isPendingCloseChannel ?? false && blockHeight <= 0
        } else if blockHeight == 0 {
            return true
        } else {
            return false
        }
    }

    public func isPending(block: UInt32) -> Bool {
        if isLightning {
            return isPendingCloseChannel ?? false && (blockHeight <= 0)
        } else if blockHeight == 0 || blockHeight == UInt32.max {
            return true
        } else if isLiquid && block < blockHeight + 1 && block >= blockHeight {
            return true
        } else if !isLiquid && block < blockHeight + 5 && block >= blockHeight {
            return true
        } else {
            return false
        }
    }

    public func confirmations(block: UInt32) -> UInt32 {
        if isLightning || blockHeight == 0 {
            return 0
        } else if blockHeight == UInt32.max {
            return blockHeight
        } else if blockHeight <= block {
            return (block - blockHeight) + 1
        } else {
            return 0
        }
    }
}
