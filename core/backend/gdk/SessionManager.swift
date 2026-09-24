import Foundation
import OSLog

import greenaddress
import hw

public enum LoginError: Error, Equatable {
    case walletsJustRestored(_ localizedDescription: String? = nil)
    case walletNotFound(_ localizedDescription: String? = nil)
    case invalidMnemonic(_ localizedDescription: String? = nil)
    case connectionFailed(_ localizedDescription: String? = nil)
    case failed(_ localizedDescription: String? = nil)
    case walletMismatch(_ localizedDescription: String? = nil)
    case hostUnblindingDisabled(_ localizedDescription: String? = nil)
}

public class SessionManager {

    public var session: GDKSession?
    public var networkId: NetworkId
    public var gdkNetwork: GdkNetwork
    public var blockHeight: UInt32 = 0
    public weak var popupResolver: PopupResolverDelegate?
    public weak var hwResolver: HwResolverDelegate?
    public weak var hwInterfaceResolver: HwInterfaceResolver?
    public var loginData: LoginUserResult?

    public var connected = false
    public var logged = false
    public var paused = false
    public var gdkFailures = [String]()
    public var hwProtocol: HWProtocol?
    public let uuid = UUID()
    public weak var newNotificationDelegate: NewNotificationDelegate?

    // Serial reconnect queue for network events
    public let reconnectionTasks = SerialTasks<Void>()

    public init(_ networkId: NetworkId) {
        self.networkId = networkId
        self.gdkNetwork = Gdk.shared.networks
            .getNetworkBy(networkId)
        session = GDKSession()
    }

    deinit {
        logged = false
        connected = false
    }

    public func connect() async throws {
        guard !connected else {
            return
        }
        let settings = GdkSettings.read()
        if settings?.tor ?? false {
            await self.networkConnect()
        }
        try await reconnectionTasks.add {
            try await self.connect(network: self.gdkNetwork.network)
            AnalyticsManager.shared.setupSession(session: self.session) // Update analytics endpoint with session tor/proxy
        }
    }

    public func disconnect() async throws {
        logged = false
        connected = false
        gdkFailures = []
        paused = false
        popupResolver = nil
        hwResolver = nil
        hwInterfaceResolver = nil
        hwProtocol = nil
        try? await reconnectionTasks.add {
            self.session = GDKSession()
        }
    }

    public func connect(network: String) async throws {
        guard !connected else {
            return
        }
        logger.info("Connecting to session \(self.networkId.rawValue)")
        do {
            gdkFailures = []
            paused = false
            session?.setNotificationHandler(notificationCompletionHandler: newNotification)
            var params = GdkSettings.read()?.toNetworkParams(network).toDict()
            try session?.connect(netParams: params ?? [:])
            connected = true
        } catch {
            switch error {
            case GaError.GenericError(let txt), GaError.SessionLost(let txt), GaError.TimeoutError(let txt):
                throw LoginError.connectionFailed(txt ?? "")
            default:
                throw LoginError.connectionFailed()
            }
        }
    }

    public func walletIdentifier(credentials: Credentials? = nil, masterXpub: String? = nil) throws -> WalletIdentifier? {
        let details = {
            if let credentials = credentials {
                return credentials.toDict()
            } else if let masterXpub = masterXpub {
                return ["master_xpub": masterXpub]
            } else {
                return nil
            }
        }()
        let netParams = GdkSettings.read()?.toNetworkParams(gdkNetwork.network).toDict()
        let res = try self.session?.getWalletIdentifier(
            net_params: netParams ?? [:],
            details: details ?? [:])
        return WalletIdentifier.from(res ?? [:]) as? WalletIdentifier
    }

    public func getWalletIdentifier(gdkNetwork: String, credentials: Credentials) throws -> WalletIdentifier? {
        let res = try self.session?.getWalletIdentifier(
            net_params: ["name": gdkNetwork],
            details: credentials.asDictionary())
        return WalletIdentifier.from(res ?? [:]) as? WalletIdentifier
    }

    public func existDatadir(masterXpub: String) -> Bool {
        if let hash = try? walletIdentifier(masterXpub: masterXpub) {
            return existDatadir(walletHashId: hash.walletHashId)
        }
        return false
    }

    public func existDatadir(credentials: Credentials) -> Bool {
        if let hash = try? walletIdentifier(credentials: credentials) {
            return existDatadir(walletHashId: hash.walletHashId)
        }
        return false
    }
    public func existDatadir(credentials: Credentials?, masterXpub: String?) -> Bool {
        if let credentials = credentials {
            return existDatadir(credentials: credentials)
        } else if let masterXpub = masterXpub {
            return existDatadir(masterXpub: masterXpub)
        } else {
            return false
        }
    }

    public func existDatadir(walletHashId: String) -> Bool {
        // true for multisig
        if gdkNetwork.multisig {
            return true
        }
        if let path = GdkInit.defaults().datadir {
            let dir = "\(path)/state/\(walletHashId)"
            return FileManager.default.fileExists(atPath: dir)
        }
        return false
    }

    public func removeDatadir(masterXpub: String) async {
        if let hash = try? walletIdentifier(masterXpub: masterXpub) {
            await removeDatadir(walletHashId: hash.walletHashId)
        }
    }

    public func removeDatadir(credentials: Credentials) async {
        if let hash = try? walletIdentifier(credentials: credentials) {
            await removeDatadir(walletHashId: hash.walletHashId)
        }
    }

    public func removeDatadir(walletHashId: String) async {
        if let path = GdkInit.defaults().datadir {
            let dir = "\(path)/state/\(walletHashId)"
            try? await reconnectionTasks.add {
                try? FileManager.default.removeItem(atPath: dir)
            }
        }
    }

    public func resolve(_ twoFactorCall: TwoFactorCall?, bcurResolver: BcurResolver? = nil, enableLogs: Bool = true) async throws -> [String: Any]? {
        let rm = ResolverManager(
            twoFactorCall,
            network: networkId,
            connected: { self.connected && self.logged && !self.paused },
            hwDevice: hwProtocol,
            session: self,
            popupResolver: popupResolver,
            hwResolver: hwResolver,
            hwInterfaceDelegate: hwInterfaceResolver,
            bcurResolver: bcurResolver,
            enableLogs: enableLogs)
        return try await rm.run()
    }

    @discardableResult
    func resolve(
        bcurResolver: BcurResolver? = nil,
        enableLogs: Bool = true,
        _ call: (Session) throws -> TwoFactorCall?
    ) async throws -> [String: Any]? {
        try await resolve(try call(try await getSession()), bcurResolver: bcurResolver, enableLogs: enableLogs)
    }

    public func transactions(subaccount: UInt32, first: Int = 0, count: Int = 30) async throws -> Transactions {
        let params = GetTransactionsParams(
            subaccount: subaccount,
            first: first,
            count: count
        )
        return try await transactions(params)
    }

    public func transactions(_ params: GetTransactionsParams) async throws -> Transactions {
        let res = try await wrap(
            fun: self.session?.getTransactions,
            params: params.toDict() ?? [:]
        )
        let result = res["result"] as? [String: Any]
        let dict = result?["transactions"] as? [[String: Any]]
        let list = dict?.map { Transaction($0) }
        return Transactions(list: list ?? [])
    }

    public func subaccount(_ pointer: UInt32) async throws -> Account {
        let subaccount = try self.session?.getSubaccount(subaccount: pointer)
        let res = try await resolve(subaccount)
        let result = res?["result"] as? [String: Any]
        var account = Account.from(result ?? [:]) as? Account
        guard var account else {
            throw GaError.GenericError("Failed to parse account")
        }
        account.networkInjected = self.gdkNetwork
        return account
    }

    public func subaccounts(_ refresh: Bool = false) async throws -> [Account] {
        let params = GetSubaccountsParams(refresh: refresh)
        let res: GetSubaccountsResult = try await wrapper(fun: self.session?.getSubaccounts, params: params)
        var wallets = res.subaccounts
        for w in wallets.enumerated() {
            wallets[w.offset].networkInjected = self.gdkNetwork
        }
        return wallets.sorted()
    }

    public func parseTxInput(_ input: String, satoshi: Int64?, assetId: String?, network: NetworkId?) async throws -> ValidateAddresseesResult {
        let asset = assetId == AssetInfo.btcId ? nil : assetId
        let addressee = Addressee.from(address: input, satoshi: satoshi, assetId: asset)
        let addressees = ValidateAddresseesParams(addressees: [addressee], network: network?.network ?? gdkNetwork.network)
        return try await self.wrapper(fun: self.session?.validate, params: addressees)
    }

    public func getSession() async throws -> Session {
        guard let session else {
            throw GaError.GenericError("Not connected")
        }
        return session
    }

    public func reconnect() async throws {
        _ = try await wrap(fun: self.session?.loginUserSW, params: [:])
    }

    public func loginUser(_ params: Credentials) async throws -> LoginUserResult {
        try await connect()
        logger.info("Connecting to login session \(self.networkId.rawValue)")
        let res: LoginUserResult = try await self.wrapper(fun: self.session?.loginUserSW, params: params)
        loginData = res
        logged = true
        return res
    }

    public func loginUser(_ params: HWDevice) async throws -> LoginUserResult {
        try await connect()
        logger.info("Connecting to login session \(self.networkId.rawValue)")
        let res: LoginUserResult = try await self.wrapper(fun: self.session?.loginUserHW, params: params)
        loginData = res
        logged = true
        return res
    }

    typealias GdkFunc = ([String: Any]) throws -> TwoFactorCall

    private let maskFields = [
        "pin",
        "mnemonic",
        "password",
        "recovery_mnemonic",
        "seed",
        "bip39_passphrase",
        "private_key",
        "device_key",
        "master_blinding_key",
        "pin_data",
        "encrypted_data",
        "core_descriptors",
        "slip132_extended_pubkey",
        "slip132_extended_pubkeys",
        "plaintext",
        "salt",
        "gauth",
        "master_xpub",
        "xpub",
        "xpubs",
        "amountblinder",
        "amountblinders",
        "assetblinder",
        "assetblinders",
        "blinding_key",
        "blinding_nonce",
        "nonces",
        "address",
        "addresses",
        "addressee",
        "addressees",
        "script",
        "scripts",
        "scriptpubkey",
        "txhash",
        "txid"
    ]

    private let redactedValue = "**Redacted**"

    private func isSensitive(_ key: String) -> Bool {
        // Suffix match, mirrors Android's key.endsWith(field) behaviour
        maskFields.contains { key.hasSuffix($0) }
    }

    private func redact(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            var masked: [String: Any] = [:]
            for (key, value) in dict {
                masked[key] = isSensitive(key) ? redactedValue : redact(value)
            }
            return masked
        }
        if let array = value as? [Any] {
            return array.map { redact($0) }
        }
        return value
    }

    private func mask(_ params: [String: Any]) -> [String: Any] {
        redact(params) as? [String: Any] ?? params
    }

    func log(
        _ funcName: String,
        _ params: [String: Any]
    ) {
        let params = mask(params).stringify() ?? ""
        logger.info("GDK \(self.gdkNetwork.network, privacy: .public) \(funcName, privacy: .public) \(params, privacy: .public)")
    }

    func logError(_ funcName: String, error: Error) {
        if let error = error as? TwoFactorCallError {
            switch error {
            case .failure(let txt):
                logger.error("GDK \(self.gdkNetwork.network, privacy: .public) \(funcName, privacy: .public) \(error, privacy: .public): \(txt, privacy: .public)")
            case .cancel(let txt):
                logger.error("GDK \(self.gdkNetwork.network, privacy: .public) \(funcName, privacy: .public) \(error, privacy: .public): \(txt, privacy: .public)")
            }
        } else if let error = error as? GaError {
            switch error {
            case .GenericError(let txt):
                logger.error("GDK \(self.gdkNetwork.network, privacy: .public) \(funcName, privacy: .public) \(error, privacy: .public)")
            case .ReconnectError(let txt):
                logger.error("GDK \(self.gdkNetwork.network, privacy: .public) \(funcName, privacy: .public) \(error, privacy: .public): \(txt ?? "", privacy: .public)")
            case .SessionLost(let txt):
                logger.error("GDK \(self.gdkNetwork.network, privacy: .public) \(funcName, privacy: .public) \(error, privacy: .public): \(txt ?? "", privacy: .public)")
            case .TimeoutError(let txt):
                logger.error("GDK \(self.gdkNetwork.network, privacy: .public) \(funcName, privacy: .public) \(error, privacy: .public): \(txt ?? "", privacy: .public)")
            case .NotAuthorizedError(let txt):
                logger.error("GDK \(self.gdkNetwork.network, privacy: .public) \(funcName, privacy: .public) \(error, privacy: .public): \(txt ?? "", privacy: .public)")
            }
        } else {
            logger.error("GDK \(self.gdkNetwork.network, privacy: .public) \(funcName, privacy: .public) \(error, privacy: .public)")
        }
    }

    func wrap(
        fun: GdkFunc?,
        params: Dictionary<String, Any>,
        funcName: String = #function,
        bcurResolver: BcurResolver? = nil,
        enableLogs: Bool = true
    )
    async throws -> Dictionary<String, Any> {
        if enableLogs {
            log(funcName, params)
        }
        do {
            if let fun = try fun?(params) {
                if let res = try await resolve(fun, bcurResolver: bcurResolver, enableLogs: enableLogs) {
                    if enableLogs {
                        log(funcName, res)
                    }
                    return res
                }
            }
        } catch {
            if enableLogs {
                logError(funcName, error: error)
            }
            throw error
        }
        throw GaError.GenericError()
    }

    func wrapper<T: Codable, K: Codable>(
        fun: GdkFunc?,
        params: T,
        funcName: String = #function,
        bcurResolver: BcurResolver? = nil,
        enableLogs: Bool = true
    )
    async throws -> K {
        let res = try await wrap(
            fun: fun,
            params: params.toDict() ?? [:],
            funcName: funcName,
            bcurResolver: bcurResolver,
            enableLogs: enableLogs)
        if let res = res["result"] as? K {
            return res
        } else {
            let result = res["result"] as? [String: Any]
            if let res = K.from(result ?? [:]) as? K {
                return res
            }
        }
        let error = GaError.GenericError("Invalid conversion")
        logError(funcName, error: error)
        throw error
    }

    public func decryptWithPin(_ params: DecryptWithPinParams) async throws -> Credentials {
        return try await wrapper(fun: self.session?.decryptWithPin, params: params)
    }

    public func getCredentials(password: String) async throws -> Credentials? {
        let cred = Credentials(password: password)
        let res: Credentials = try await wrapper(fun: self.session?.getCredentials, params: cred, enableLogs: false)
        return res
    }

    public func register(credentials: Credentials? = nil, hw: HWDevice? = nil) async throws {
        try await self.connect()
        // Device registration must not carry credentials (gdk rejects master_xpub
        // on multisig registration). Keep them otherwise: mnemonic registration and
        // watch-only username/password setup both go through details.
        let credentials = hw != nil ? nil : credentials
        let res = try self.session?.registerUser(details: credentials?.toDict() ?? [:], hw_device: ["device": hw?.toDict() ?? [:]])
        _ = try await resolve(res)
    }

    public func encryptWithPin(_ params: EncryptWithPinParams) async throws -> EncryptWithPinResult {
        return try await wrapper(
            fun: self.session?.encryptWithPin,
            params: params,
            enableLogs: false
        )
    }

    public func resetTwoFactor(email: String, isDispute: Bool) async throws {
        let res = try self.session?.resetTwoFactor(email: email, isDispute: isDispute)
        _ = try await resolve(res)
    }

    public func cancelTwoFactorReset() async throws {
        let res = try self.session?.cancelTwoFactorReset()
        _ = try await resolve(res)
    }

    public func undoTwoFactorReset(email: String) async throws {
        let res = try self.session?.undoTwoFactorReset(email: email)
        _ = try await resolve(res)
    }

    public func getWatchOnlyUsername() async throws -> String? {
        return try session?.getWatchOnlyUsername()
    }

    public func setCSVTime(value: Int) async throws {
        _ = try await wrap(fun: self.session?.setCSVTime, params: ["value": value])
    }

    public func setTwoFactorLimit(_ details: TwoFactorConfigLimits) async throws {
        _ = try await wrap(
            fun: self.session?.setTwoFactorLimit,
            params: details.asDictionary()
        )
    }

    public func convertAmount(input: [String: Any]) throws -> [String: Any] {
        try self.session?.convertAmount(input: input) ?? [:]
    }

    public func convertAmount(params: Balance) throws -> Balance? {
        let res = try self.session?.convertAmount(input: params.toDict() ?? [:])
        return Balance.from(res ?? [:]) as? Balance
    }

    public func refreshAssets(icons: Bool, assets: Bool) async throws {
        let params: [String: Bool] = ["icons": icons, "assets": assets]
        try self.session?.refreshAssets(params: params)
    }

    public func getReceiveAddress(subaccount: UInt32) async throws -> Address {
        let params = Address(address: nil, pointer: nil, branch: nil, subtype: nil, userPath: nil, subaccount: subaccount, addressType: nil, script: nil)
        return try await wrapper(fun: self.session?.getReceiveAddress, params: params)
    }

    public func getBalance(subaccount: UInt32, numConfs: Int) async throws -> [String: Int64] {
        let res = try await wrap(fun: self.session?.getBalance, params: ["subaccount": subaccount, "num_confs": numConfs])
        return res["result"] as? [String: Int64] ?? [:]
    }

    public func updateSubaccount(_ params: UpdateSubaccountParams) async throws {
        _ = try await wrap(fun: self.session?.updateSubaccount, params: params.toDict() ?? [:])
    }

    public func createSubaccount(_ details: CreateSubaccountParams) async throws -> Account {
        var wallet: Account = try await wrapper(fun: self.session?.createSubaccount, params: details)
        wallet.networkInjected = self.gdkNetwork
        return wallet
    }

    public func renameSubaccount(_ params: UpdateSubaccountParams) async throws {
        _ = try await wrap(fun: self.session?.updateSubaccount, params: params.toDict() ?? [:])
    }

    public func getUnspentOutputsForPrivateKey(_ params: UnspentOutputsForPrivateKeyParams) async throws -> [String: Any]? {
        let res = try await wrap(fun: self.session?.getUnspentOutputsForPrivateKey, params: params.toDict() ?? [:])
        let result = res["result"] as? [String: Any]
        return result?["unspent_outputs"] as? [String: Any]
    }

    public func getUnspentOutputs(_ params: GetUnspentOutputsParams, funcName: String = #function) async throws -> [String: [[String: Any]]] {
        let res = try await wrap(fun: self.session?.getUnspentOutputs, params: params.toDict() ?? [:])
       let result = res["result"] as? [String: Any]
        return result?["unspent_outputs"] as? [String: [[String: Any]]] ?? [:]
    }

    public func getUtxos(_ params: GetUnspentOutputsParams) async throws -> GetUnspentOutputsResult {
        return try await wrapper(fun: self.session?.getUnspentOutputs, params: params)
    }

    public func createTransaction(tx: Transaction) async throws -> Transaction {
        let res = try await wrap(fun: self.session?.createTransaction, params: tx.details)
        return Transaction(res["result"] as? [String: Any] ?? [:], accountId: tx.accountId)
    }

    public func blindTransaction(tx: Transaction) async throws -> Transaction {
        let res = try await wrap(fun: self.session?.blindTransaction, params: tx.details)
        return Transaction(res["result"] as? [String: Any] ?? [:], accountId: tx.accountId)
    }

    public func signTransaction(tx: Transaction) async throws -> Transaction {
        let res = try await wrap(fun: self.session?.signTransaction, params: tx.details)
        return Transaction(res["result"] as? [String: Any] ?? [:], accountId: tx.accountId)
    }

    public func sendTransaction(tx: Transaction) async throws -> SendTransactionSuccess {
        let res = try await wrap(fun: self.session?.sendTransaction, params: tx.details)
        let result = res["result"] as? [String: Any]
        if let res = SendTransactionSuccess.from(result ?? [:]) as? SendTransactionSuccess {
            return res
        }
        throw GaError.GenericError()
    }

    public func broadcastTransaction(_ params: BroadcastTransactionParams) async throws -> SendTransactionSuccess {
        let res: BroadcastTransactionResult = try await wrapper(fun: self.session?.broadcastTransaction, params: params)
        if params.psbt != nil {
            return SendTransactionSuccess(txHash: res.txHash, psbt: res.psbt, transaction: res.transaction)
        }
        return SendTransactionSuccess(txHash: res.txHash)
    }

    public func getFeeEstimates() async throws -> [UInt64]? {
        let estimates = try? session?.getFeeEstimates()
        return estimates == nil ? nil : estimates!["fees"] as? [UInt64]
    }

    public func loadSystemMessage() async throws -> String? {
        try self.session?.getSystemMessage()
    }

    public func ackSystemMessage(message: String) async throws {
        let res = try self.session?.ackSystemMessage(message: message)
        _ = try await resolve(res)
    }

    public func getAvailableCurrencies() async throws -> [String: [String]] {
        let res = try self.session?.getAvailableCurrencies()
        return res?["per_exchange"] as? [String: [String]] ?? [:]
    }

    public func getPreviousAddresses(_ params: GetPreviousAddressesParams) async throws -> GetPreviousAddressesResult? {
        return try await wrapper(fun: self.session?.getPreviousAddresses, params: params)
    }

    public func signMessage(_ params: SignMessageParams) async throws -> SignMessageResult? {
        return try await wrapper(fun: self.session?.signMessage, params: params)
    }

    public func validBip21Uri(uri: String) -> Bool {
        if let prefix = gdkNetwork.bip21Prefix {
            return uri.starts(with: prefix)
        }
        return false
    }

    public func getAssets(params: GetAssetsParams) -> GetAssetsResult? {
        if let res = try? session?.getAssets(params: params.toDict() ?? [:]) {
            return GetAssetsResult.from(res) as? GetAssetsResult
        }
        return nil
    }

    public func networkConnect() async {
        try? await reconnectionTasks.add {
            let hint = ReconnectHintParams(torHint: "connect", hint: "connect")
            self.log("reconnectHint", hint.toDict() ?? [:])
            try? self.session?.reconnectHint(hint: hint.toDict() ?? [:])
        }
    }

    public func networkDisconnect() async {
        paused = true
        try? await reconnectionTasks.add {
            let hint = ReconnectHintParams(torHint: "disconnect", hint: "disconnect")
            self.log("reconnectHint", hint.toDict() ?? [:])
            try? self.session?.reconnectHint(hint: hint.toDict() ?? [:])
        }
    }

    public func httpRequest(params: [String: Any]) -> [String: Any]? {
        return try? session?.httpRequest(params: params)
    }

    public func bcurEncode(params: BcurEncodeParams) async throws -> BcurEncodedData? {
        try? await connect()
        return try await wrapper(fun: self.session?.bcurEncode, params: params, enableLogs: false)
    }

    public func bcurDecode(params: BcurDecodeParams, bcurResolver: BcurResolver) async throws -> BcurDecodedData? {
        try await connect()
        let res = try await wrap(fun: self.session?.bcurDecode, params: params.toDict() ?? [:], bcurResolver: bcurResolver, enableLogs: false)
        return res["result"] as? BcurDecodedData
    }

    public func jadeBip8539Request(index: UInt32) async throws -> (Data?, BcurEncodedData?) {
        let privateKey = createEcKey()
        let params = BcurEncodeParams(
            urType: "jade-bip8539-request",
            numWords: 12,
            index: index,
            privateKey: privateKey?.hex
        )
        let data = try await bcurEncode(params: params)
        return (privateKey, data)
    }

    public func jadeBip8539Reply(privateKey: Data, publicKey: Data, encrypted: Data) async -> String? {
        return Wally.bip85FromJade(
            privateKey: [UInt8](privateKey),
            publicKey: [UInt8](publicKey),
            label: "bip85_bip39_entropy",
            payload: [UInt8](encrypted))
    }

    public func createEcKey() -> Data? {
        var privateKey: Data?
        repeat {
            privateKey = secureRandomData(count: Wally.EC_PRIVATE_KEY_LEN)
        } while(privateKey != nil && !Wally.ecPrivateKeyVerify(privateKey: [UInt8](privateKey!)))
        return privateKey
    }
    
    public func getPsbt(tx: Transaction) async throws -> String? {
        let res = try await wrap(fun: session?.PsbtFromJSON, params: tx.details)
        let result = res["result"] as? [String: Any]
        return result?["psbt"] as? String
    }

    public func createRedepositTransaction(params: CreateRedepositTransactionParams) async throws -> Transaction {
        let res = try await wrap(fun: session?.createRedepositTransaction, params: params.toDict() ?? [:])
        let result = res["result"] as? [String: Any]
        return Transaction(result ?? [:], accountId: nil)
    }

    public func psbtGetDetails(params: PsbtGetDetailParams) async throws -> Transaction {
        let res = try await wrap(fun: session?.PsbtGetDetails, params: params.toDict() ?? [:])
        let result = res["result"] as? [String: Any]
        return Transaction(result ?? [:], accountId: nil)
    }
    
    public func signPsbt(params: SignPsbtParams) async throws -> SignPsbtResult {
        try await wrapper(fun: session?.signPsbt, params: params)
    }
    
    public func rsaVerify(details: RSAVerifyParams) async throws -> RSAVerifyResult {
        try await wrapper(fun: session?.rsaVerify, params: details)
    }

    public func reconnectHint(hint: ReconnectHintParams) async throws {
        try session?.reconnectHint(hint: hint.toDict() ?? [:])
    }

    public func connectHint() async throws {
        let hint = ReconnectHintParams(torHint: "connect", hint: "connect")
        try await reconnectHint(hint: hint)
    }
    public func disconnectHint() async throws {
        let hint = ReconnectHintParams(torHint: "disconnect", hint: "disconnect")
        try await reconnectHint(hint: hint)
    }
}


extension SessionManager {
    public func getTwoFactorConfig() async throws -> TwoFactorConfig {
        return try await getSession().getTwoFactorConfig().decode()
    }

    public func getSettings() async throws -> Settings {
        return try await getSession().getSettings().decode()
    }

    public func changeSettings(_ params: Settings) async throws {
        try await resolve {
            try $0.changeSettings(details: params.asDictionary())
        }
    }
    public func changeSettingsTwoFactor(_ params: ChangeSettingsTwoFactorParams) async throws {
        try await resolve { try $0.changeSettingsTwoFactor(method: params.method.rawValue, details: params.config.asDictionary()) }
    }
}

extension SessionManager {
    public func newNotification(notification: [String: Any]?) {
        guard let notificationEvent = notification?["event"] as? String,
                let event = EventType(rawValue: notificationEvent),
                let data = notification?[event.rawValue] as? [String: Any] else {
            return
        }
        logger.info("newNotification \(notification?.stringify()?.prefix(100) ?? "", privacy: .public)")
        switch event {
        case .Block:
            if let block = Block.from(data) as? Block {
                blockHeight = block.height
                newNotificationDelegate?.didReceive(event: .newBlock(block: block), networkId: networkId)
            }
        case .Subaccount:
            guard let subaccountEvent = SubaccountEvent.from(data) as? SubaccountEvent else { break }
            newNotificationDelegate?.didReceive(event: .newSubaccount(subaccount: subaccountEvent), networkId: networkId)
        case .Transaction:
            guard let txEvent = TransactionEvent.from(data) as? TransactionEvent else { break }
            newNotificationDelegate?.didReceive(event: .newTransaction(transaction: txEvent), networkId: networkId)
        case .TwoFactorReset:
                newNotificationDelegate?.didReceive(event: .twoFactorReset, networkId: networkId)
        case .Settings:
            if let settings = try? data.decode(Settings.self) {
                newNotificationDelegate?
                    .didReceive(event: .updateSettings(settings: settings), networkId: networkId)
            }
        case .Network:
            guard let connection = Connection.from(data) as? Connection else { return }
            let hasElectrumUrl = !(getPersonalElectrumServer()?.isEmpty ?? true)
            if !logged && gdkNetwork.singlesig && hasElectrumUrl && connection.currentState == "disconnected" {
                let msg = "Your Personal Electrum Server for %@ can\'t be reached. Check your settings or your internet connection."
                gdkFailures = [String(format: msg, gdkNetwork.chain)]
                return
            }
            // avoid handling notification for unlogged session
            guard connected && logged else { return }
            // notify disconnected network state
            if connection.currentState == "disconnected" {
                paused = true
                newNotificationDelegate?.didReceive(event: .disconnected, networkId: networkId)
                return
            }
            // Restore connection through hidden login
            Task {
                do {
                    logger.info("GDK \(self.gdkNetwork.network, privacy: .public) reconnect")
                    try await reconnect()
                    logger.info("GDK \(self.gdkNetwork.network, privacy: .public) reconnected")
                    paused = false
                    newNotificationDelegate?.didReceive(event: .reconnected, networkId: networkId)
                } catch {
                    logger.error("GDK Error on reconnected: \(error.localizedDescription, privacy: .public)")
                }
            }
        case .Tor:
            if let torData = TorNotification.from(data) as? TorNotification {
                newNotificationDelegate?.didReceive(event: .tor(data: torData), networkId: networkId)
            }
        case .Ticker:
            break
        case .AssetsUpdated:
            newNotificationDelegate?.didReceive(event: .refreshAssets, networkId: networkId)
        default:
            break
        }
    }

    public func getPersonalElectrumServer() -> String? {
        return session?.netParams["electrum_url"] as? String
    }
}
