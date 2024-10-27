import Foundation
import greenaddress

public struct WalletIdentifier: Codable {
    enum CodingKeys: String, CodingKey {
        case walletHashId = "wallet_hash_id"
        case xpubHashId = "xpub_hash_id"
    }
    public let walletHashId: String
    public let xpubHashId: String
    public init(walletHashId: String, xpubHashId: String) {
        self.walletHashId = walletHashId
        self.xpubHashId = xpubHashId
    }
}

public struct SystemMessage: Codable {
    enum CodingKeys: String, CodingKey {
        case text
        case network
    }
    public let text: String
    public let network: String

    public init(text: String,
                network: String) {
        self.text = text
        self.network = network
    }
}

public struct TwoFactorResetMessage: Codable {
    public enum CodingKeys: String, CodingKey {
        case twoFactorReset
        case network
    }
    public let twoFactorReset: TwoFactorReset
    public let network: String
    public init(twoFactorReset: TwoFactorReset, network: String) {
        self.twoFactorReset = twoFactorReset
        self.network = network
    }
}

public struct DecryptWithPinParams: Codable {
    enum CodingKeys: String, CodingKey {
        case pin
        case pinData  = "pin_data"
    }
    public let pin: String
    public let pinData: PinData

    public init(pin: String, pinData: PinData) {
        self.pin = pin
        self.pinData = pinData
    }
}

public struct EncryptWithPinParams: Codable {
    enum CodingKeys: String, CodingKey {
        case pin
        case plaintext
    }
    public let pin: String
    public let plaintext: Credentials

    public init(pin: String, credentials: Credentials) {
        self.pin = pin
        self.plaintext = credentials
    }
}

public struct EncryptWithPinResult: Codable {
    enum CodingKeys: String, CodingKey {
        case pinData = "pin_data"
    }
    public let pinData: PinData
}

public struct LoginUserResult: Codable {
    enum CodingKeys: String, CodingKey {
        case xpubHashId = "xpub_hash_id"
        case walletHashId = "wallet_hash_id"
    }
    public let xpubHashId: String
    public let walletHashId: String
    public init(xpubHashId: String, walletHashId: String) {
        self.xpubHashId = xpubHashId
        self.walletHashId = walletHashId
    }
}

public struct GetSubaccountsParams: Codable {
    enum CodingKeys: String, CodingKey {
        case refresh
    }
    public let refresh: Bool

    public init(refresh: Bool) {
        self.refresh = refresh
    }
}

public struct GetSubaccountsResult: Codable {
    enum CodingKeys: String, CodingKey {
        case subaccounts
    }
    public let subaccounts: [WalletItem]
}

public struct GetSubaccountParams: Codable {
    enum CodingKeys: String, CodingKey {
        case pointer
    }
    public let pointer: UInt32
}

public struct GetAssetsParams: Codable {
    enum CodingKeys: String, CodingKey {
        case assetsId = "assets_id"
    }
    public let assetsId: [String]

    public init(assetsId: [String]) {
        self.assetsId = assetsId
    }
}

public struct GetAssetsResult: Codable {
    public let assets: [String: AssetInfo]
    public let icons: [String: String]
}

public struct ValidateAddresseesParams: Codable {
    public let addressees: [Addressee]
    public let network: String?
    public init(addressees: [Addressee], network: String) {
        self.addressees = addressees
        self.network = network
    }
}

public struct SignMessageParams: Codable {
    enum CodingKeys: String, CodingKey {
        case address
        case message
    }
    public let address: String
    public let message: String
    public init(address: String, message: String) {
        self.address = address
        self.message = message
    }
}

public struct SignMessageResult: Codable {
    enum CodingKeys: String, CodingKey {
        case signature
    }
    public let signature: String
    public init(signature: String) {
        self.signature = signature
    }
}

public struct SendTransactionSuccess: Codable {
    enum CodingKeys: String, CodingKey {
        case txHash = "txhash"
        case sendAll = "send_all"
        case signedTransaction = "signed_transaction"
        case paymentId = "payment_id"
        case message
        case url
        case psbt
        case transaction
    }
    public let txHash: String?
    public var sendAll: Bool?
    public let signedTransaction: String?
    public let paymentId: String?
    public let message: String?
    public let url: String?
    public let psbt: String?
    public let transaction: String?
    
    public init(txHash: String? = nil, sendAll: Bool? = nil, signedTransaction: String? = nil, paymentId: String? = nil, message: String? = nil, url: String? = nil, psbt: String? = nil, transaction: String? = nil) {
        self.txHash = txHash
        self.sendAll = sendAll
        self.signedTransaction = signedTransaction
        self.paymentId = paymentId
        self.message = message
        self.url = url
        self.psbt = psbt
        self.transaction = transaction
    }
}

public struct CreateRedepositTransactionParams: Codable {
    enum CodingKeys: String, CodingKey {
        case utxos
        case feeRate = "fee_rate"
        case feeSubaccount = "fee_subaccount"
    }
    public let utxos: [String: [UnspentOutput]]
    public let feeRate: UInt64?
    public let feeSubaccount: UInt32
    public init(utxos: [String: [UnspentOutput]], feeRate: UInt64?, feeSubaccount: UInt32) {
        self.utxos = utxos
        self.feeRate = feeRate
        self.feeSubaccount = feeSubaccount
    }
}

public typealias CreateRedepositTransactionResult = Transaction

public struct PsbtGetDetailParams: Codable {
    enum CodingKeys: String, CodingKey {
        case psbt
        case utxos
    }
    public let psbt: String?
    public let utxos: [String: [UnspentOutput]]
     public init(psbt: String? = nil, utxos: [String: [UnspentOutput]]) {
        self.psbt = psbt
        self.utxos = utxos
    }
}

public struct GetPreviousAddressesParams: Codable {
    enum CodingKeys: String, CodingKey {
        case subaccount
        case lastPointer = "last_pointer"
    }
    public let subaccount: Int
    public let lastPointer: Int?
    public init(subaccount: Int, lastPointer: Int?) {
        self.subaccount = subaccount
        self.lastPointer = lastPointer
    }
}

public struct GetPreviousAddressesResult: Codable {
    enum CodingKeys: String, CodingKey {
        case list
        case lastPointer = "last_pointer"
    }
    public let list: [Address]
    public let lastPointer: Int?
    public init(list: [Address], lastPointer: Int?) {
        self.list = list
        self.lastPointer = lastPointer
    }
}

public struct ValidateAddresseesResult: Codable {
    enum CodingKeys: String, CodingKey {
        case isValid = "is_valid"
        case errors
        case addressees
    }
    public let isValid: Bool
    public let errors: [String]
    public let addressees: [Addressee]
    public init(isValid: Bool, errors: [String], addressees: [Addressee]) {
        self.isValid = isValid
        self.errors = errors
        self.addressees = addressees
    }
}

public struct CreateSubaccountParams: Codable {
    enum CodingKeys: String, CodingKey {
        case name = "name"
        case type = "type"
        case recoveryMnemonic = "recovery_mnemonic"
        case recoveryXpub = "recovery_xpub"
    }

    public let name: String
    public let type: AccountType
    public let recoveryMnemonic: String?
    public let recoveryXpub: String?

    public init(name: String, type: AccountType, recoveryMnemonic: String? = nil, recoveryXpub: String? = nil) {
        self.name = name
        self.type = type
        self.recoveryMnemonic = recoveryMnemonic
        self.recoveryXpub = recoveryXpub
    }
}

public struct UnspentOutputsForPrivateKeyParams: Codable {
    enum CodingKeys: String, CodingKey {
        case privateKey = "private_key"
        case password
    }

    public let privateKey: String
    public let password: String?

    public init(privateKey: String, password: String?) {
        self.privateKey = privateKey
        self.password = password
    }
}

public struct ResolveCodeData: Codable {
    enum CodingKeys: String, CodingKey {
        case attemptsRemaining = "attempts_remaining"
        case status
        case name
        case method
        case action
    }
    let attemptsRemaining: Int64?
    let status: String?
    let name: String?
    let method: String?
    let action: String?
}

public struct ResolveCodeAuthData: Codable {
    enum CodingKeys: String, CodingKey {
        case estimatedProgress = "estimated_progress"
        case receivedIndices = "received_indices"
    }
    public let estimatedProgress: Int?
    public let receivedIndices: [Int]?
    internal init(estimatedProgress: Int? = nil, receivedIndices: [Int]? = nil) {
        self.estimatedProgress = estimatedProgress
        self.receivedIndices = receivedIndices
    }
}

public struct BcurDecodeParams: Codable {
    enum CodingKeys: String, CodingKey {
        case part
    }
    public let part: String
    public init(part: String) {
        self.part = part
    }
}

public struct BcurEncodedData: Codable {
    enum CodingKeys: String, CodingKey {
        case parts
    }
    public let parts: [String]
    public init(parts: [String]) {
        self.parts = parts
    }
}

public struct BcurEncodeParams: Codable {
    enum CodingKeys: String, CodingKey {
        case urType = "ur_type"
        case data
        case numWords = "num_words"
        case index
        case privateKey = "private_key"
        case maxFragmentLen = "max_fragment_len"
    }
    public let urType: String
    public let data: String?
    public let numWords: Int?
    public let index: Int?
    public let privateKey: String?
    public let maxFragmentLen: Int?
    public init(urType: String, data: String? = nil, numWords: Int? = nil, index: Int? = nil, privateKey: String? = nil, maxFragmentLen: Int = 40) {
        self.urType = urType
        self.data = data
        self.numWords = numWords
        self.index = index
        self.privateKey = privateKey
        self.maxFragmentLen = maxFragmentLen
    }
}
public typealias BcurDecodedData = [String: Any?]

extension BcurDecodedData {
    private func get<T>(_ key: String) -> T? {
        return self[key] as? T
    }
    public var urType: String? { self.get("ur_type") }
    public var data: String? { self.get("data") }
    public var psbt: String? { self.get("psbt") }
    public var descriptor: String? { self.get("descriptor") }
    public var descriptors: [String]? { self.get("descriptors") }
    public var masterFingerprint: String? { self.get("master_fingerprint") }
    public var encrypted: String? { self.get("encrypted") }
    public var publicΚey: String? { self.get("public_key") }
    public var res: [String: Any?]? { self.get("result") }
    //public var result: String {
    //    descriptors?.joined(separator: ",") ?? descriptor ?? psbt ?? data ?? ""
    //}
}
public struct GetUnspentOutputsParams: Codable {
    enum CodingKeys: String, CodingKey {
        case subaccount
        case numConfs = "num_confs"
        case addressType = "address_type"
        case allCoins = "all_coins"
        case expiredAt = "expired_at"
        case confidential
        case dustLimit = "dust_limit"
        case sortBy = "sort_by"
    }
    public let subaccount: UInt32
    public let numConfs: Int?
    public let addressType: String?
    public let allCoins: Bool?
    public let expiredAt: UInt64?
    public let confidential: Bool?
    public let dustLimit: UInt64?
    public let sortBy: String?

    public init(subaccount: UInt32, numConfs: Int? = nil, addressType: String? = nil, allCoins: Bool? = nil, expiredAt: UInt64? = nil, confidential: Bool? = nil, dustLimit: UInt64? = nil, sortBy: String? = nil) {
        self.subaccount = subaccount
        self.numConfs = numConfs
        self.addressType = addressType
        self.allCoins = allCoins
        self.expiredAt = expiredAt
        self.confidential = confidential
        self.dustLimit = dustLimit
        self.sortBy = sortBy
    }
}
public struct GetUnspentOutputsResult: Codable {
    enum CodingKeys: String, CodingKey {
        case unspentOutputs = "unspent_outputs"
    }
    public let unspentOutputs: [String: [UnspentOutput]]
}

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
}

public struct BroadcastTransactionParams: Codable {
    enum CodingKeys: String, CodingKey {
        case transaction
        case psbt
        case memo
        case simulateOnly = "simulate_only"
    }
    public let transaction: String?
    public let psbt: String?
    public let memo: String?
    public let simulateOnly: Bool?
    public init(transaction: String? = nil, psbt: String? = nil, memo: String? = nil, simulateOnly: Bool? = nil) {
        self.transaction = transaction
        self.psbt = psbt
        self.memo = memo
        self.simulateOnly = simulateOnly
    }
}

public struct BroadcastTransactionResult: Codable {
    enum CodingKeys: String, CodingKey {
        case transaction
        case psbt
        case txHash = "txhash"
    }
    public let transaction: String?
    public let psbt: String?
    public let txHash: String?
}

public struct SignPsbtParams: Codable {
    enum CodingKeys: String, CodingKey {
        // The PSBT or PSET encoded in base64 format.
        case psbt
        // Mandatory. The UTXOs that should be signed, Unspent outputs JSON as returned by GA_get_unspent_outputs
        case utxos
        // For "2of2_no_recovery" subaccounts only, the blinding nonces in hex format for all outputs.
        case blindingNonces = "blinding_nonces"
    }
    public let psbt: String
    public let utxos: [String: [UnspentOutput]]
    public let blindingNonces: [String]?
    public init(psbt: String, utxos: [String: [UnspentOutput]], blindingNonces: [String]? = nil) {
        self.psbt = psbt
        self.utxos = utxos
        self.blindingNonces = blindingNonces
    }
}

public struct SignPsbtResult: Codable {
    enum CodingKeys: String, CodingKey {
        case psbt
        case txhash
        case error
    }
    public let psbt: String
    public let txhash: String
    public let error: String?
}

public struct GdkInit: Codable {
    enum CodingKeys: String, CodingKey {
        case datadir
        case tordir
        case registrydir
        case logLevel = "log_level"
        case optimizeExpiredCsv = "optimize_expired_csv"
    }
    public let datadir: String?
    public let tordir: String?
    public let registrydir: String?
    public let logLevel: String
    public let optimizeExpiredCsv: Bool?

    public static func defaults() -> GdkInit {
        let appSupportDir = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let cacheDir = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        var logLevel = "none"
#if DEBUG
        logLevel = "info"
#endif
        return GdkInit(datadir: appSupportDir?.path,
                       tordir: cacheDir?.path,
                       registrydir: cacheDir?.path,
                       logLevel: logLevel,
                       optimizeExpiredCsv: true)
    }

    public func run() {
        try? gdkInit(config: self.toDict() ?? [:])
    }
}
