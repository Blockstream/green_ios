import Foundation
import UIKit
import gdk
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


public actor SerialTasks<Success> {
    private var previousTask: Task<Success, Error>?

    func add(block: @Sendable @escaping () async throws -> Success) async throws -> Success {
        let task = Task { [previousTask] in
            let _ = await previousTask?.result
            return try await block()
        }
        previousTask = task
        return try await task.value
    }
}

public class SessionManager {
    
    //var notificationManager: NotificationManager?
    public var twoFactorConfig: TwoFactorConfig?
    public var settings: Settings?
    public var session: GDKSession?
    public var gdkNetwork: GdkNetwork
    public var blockHeight: UInt32 = 0
    public var popupResolver: PopupResolverDelegate? = nil
    
    public var connected = false
    public var logged = false
    public var paused = false
    public var gdkFailures = [String]()
    public weak var hw: BLEDevice?
    public let uuid = UUID()
    
    // Serial reconnect queue for network events
    public let reconnectionTasks = SerialTasks<Void>()

    public var networkType: NetworkSecurityCase {
        NetworkSecurityCase(rawValue: gdkNetwork.network) ?? .bitcoinSS
    }

    public var isResetActive: Bool? {
        get { twoFactorConfig?.twofactorReset.isResetActive }
    }
    
    public init(_ gdkNetwork: GdkNetwork) {
        self.gdkNetwork = gdkNetwork
        session = GDKSession()
    }
    
    deinit {
        logged = false
        connected = false
    }
    
    public func connect() async throws {
        if connected {
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
        try? await reconnectionTasks.add {
            self.session = GDKSession()
        }
    }
    
    private func connect(network: String) async throws {
        do {
            gdkFailures = []
            paused = false
            session?.setNotificationHandler(notificationCompletionHandler: newNotification)
            try session?.connect(netParams: GdkSettings.read()?.toNetworkParams(network).toDict() ?? [:])
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
    
    public func walletIdentifier(credentials: Credentials) throws -> WalletIdentifier? {
        let res = try self.session?.getWalletIdentifier(
            net_params: GdkSettings.read()?.toNetworkParams(gdkNetwork.network).toDict() ?? [:],
            details: credentials.toDict() ?? [:])
        return WalletIdentifier.from(res ?? [:]) as? WalletIdentifier
    }
    
    public func walletIdentifier(masterXpub: String) throws -> WalletIdentifier? {
        let details = ["master_xpub": masterXpub]
        let res = try self.session?.getWalletIdentifier(
            net_params: GdkSettings.read()?.toNetworkParams(gdkNetwork.network).toDict() ?? [:],
            details: details)
        return WalletIdentifier.from(res ?? [:]) as? WalletIdentifier
    }
    
    public func existDatadir(masterXpub: String) -> Bool  {
        if let hash = try? walletIdentifier(masterXpub: masterXpub) {
            return existDatadir(walletHashId: hash.walletHashId)
        }
        return false
    }
    
    public func existDatadir(credentials: Credentials) -> Bool  {
        if let hash = try? walletIdentifier(credentials: credentials) {
            return existDatadir(walletHashId: hash.walletHashId)
        }
        return false
    }
    
    public func existDatadir(walletHashId: String) -> Bool  {
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
    
    public func resolve(_ twoFactorCall: TwoFactorCall?, bcurResolver: BcurResolver? = nil) async throws -> [String: Any]? {
        let rm = ResolverManager(
            twoFactorCall,
            network: networkType,
            connected: { self.connected && self.logged && !self.paused },
            hwDevice: hw?.interface,
            session: self,
            popupResolver: popupResolver,
            bcurResolver: bcurResolver)
        return try await rm.run()
    }
    
    public func transactions(subaccount: UInt32, first: UInt32 = 0) async throws -> Transactions {
        let txs = try self.session?.getTransactions(details: ["subaccount": subaccount,
                                                              "first": first,
                                                              "count": 30])
        let res = try await resolve(txs)
        let result = res?["result"] as? [String: Any]
        let dict = result?["transactions"] as? [[String: Any]]
        let list = dict?.map { Transaction($0) }
        return Transactions(list: list ?? [])
    }
    
    public func subaccount(_ pointer: UInt32) async throws -> WalletItem? {
        let subaccount = try self.session?.getSubaccount(subaccount: pointer)
        let res = try await resolve(subaccount)
        let result = res?["result"] as? [String: Any]
        let wallet = WalletItem.from(result ?? [:]) as? WalletItem
        wallet?.network = self.gdkNetwork.network
        return wallet
    }

    public func subaccounts(_ refresh: Bool = false) async throws -> [WalletItem] {
        let params = GetSubaccountsParams(refresh: refresh)
        let res: GetSubaccountsResult = try await wrapperAsync(fun: self.session?.getSubaccounts, params: params)
        let wallets = res.subaccounts
        wallets.forEach { $0.network = self.gdkNetwork.network }
        return wallets.sorted()
    }
    
    public func parseTxInput(_ input: String, satoshi: Int64?, assetId: String?) async throws -> ValidateAddresseesResult {
        let asset = assetId == AssetInfo.btcId ? nil : assetId
        let addressee = Addressee.from(address: input, satoshi: satoshi, assetId: asset)
        let addressees = ValidateAddresseesParams(addressees: [addressee])
        return try await self.wrapperAsync(fun: self.session?.validate, params: addressees)
    }
    
    @discardableResult
    public func loadTwoFactorConfig() async throws -> TwoFactorConfig? {
        if let dataTwoFactorConfig = try self.session?.getTwoFactorConfig() {
            print(dataTwoFactorConfig)
            let res = TwoFactorConfig.from(dataTwoFactorConfig) as? TwoFactorConfig
            self.twoFactorConfig = res
        }
        return self.twoFactorConfig
    }
    
    public func loadSettings() async throws -> Settings? {
        if let data = try self.session?.getSettings() {
            self.settings = Settings.from(data)
        }
        return self.settings
    }
    
    // create a default segwit account if doesn't exist on singlesig
    public func createDefaultSubaccount(wallets: [WalletItem]) async throws {
        let notFound = !wallets.contains(where: {$0.type == AccountType.segWit })
        if gdkNetwork.electrum && notFound {
            let res = try self.session?.createSubaccount(details: ["name": "", "type": AccountType.segWit.rawValue])
            _ = try await resolve(res)
        }
    }
    
    public func reconnect() async throws {
        let res = try self.session?.loginUserSW(details: [:])
        _ = try await resolve(res)
    }
    
    public func loginUser(_ params: Credentials, restore: Bool) async throws -> LoginUserResult {
        try await connect()
        let res: LoginUserResult = try await self.wrapperAsync(fun: self.session?.loginUserSW, params: params)
        try await onLogin(res)
        return res
    }
    
    public func loginUser(_ params: HWDevice, restore: Bool) async throws -> LoginUserResult {
        try await connect()
        let res: LoginUserResult = try await self.wrapperAsync(fun: self.session?.loginUserHW, params: params)
        try await onLogin(res)
        return res
    }
    
    public func loginUser(credentials: Credentials? = nil, hw: HWDevice? = nil, restore: Bool) async throws -> LoginUserResult {
        if let credentials = credentials {
            return try await loginUser(credentials, restore: restore)
        } else if let hw = hw {
            return try await loginUser(hw, restore: restore)
        } else {
            throw GaError.GenericError("No login method specified")
        }
    }
    
    private func onLogin(_ data: LoginUserResult) async throws {
        logged = true
        if self.gdkNetwork.multisig {
            //try await self.loadTwoFactorConfig()
        }
    }
    
    typealias GdkFunc = ([String: Any]) throws -> TwoFactorCall

    func wrapperAsync<T: Codable, K: Codable>(
        fun: GdkFunc?,
        params: T,
        funcName: String = #function,
        bcurResolver: BcurResolver? = nil
    )
    async throws -> K {
        let dict = params.toDict()
        NSLog("GDK \(funcName) \(params.stringify() ?? "")")
        if let fun = try fun?(dict ?? [:]) {
            let res = try await resolve(fun, bcurResolver: bcurResolver)
            NSLog("GDK \(funcName) \(res ?? [:])")
            let result = res?["result"] as? [String: Any]
            if let res = K.from(result ?? [:]) as? K {
                return res
            }
        }
        throw GaError.GenericError()
    }
    
    public func decryptWithPin(_ params: DecryptWithPinParams) async throws -> Credentials {
        return try await wrapperAsync(fun: self.session?.decryptWithPin, params: params)
    }
    
    public func load(refreshSubaccounts: Bool = true) async throws {
        if refreshSubaccounts {
            do {
                _ = try await self.subaccounts(true)
            } catch { }
            let subaccounts = try await self.subaccounts(false)
            _ = try await createDefaultSubaccount(wallets: subaccounts)
        }
    }
    
    public func getCredentials(password: String) async throws -> Credentials? {
        let cred = Credentials(password: password)
        let res: Credentials = try await wrapperAsync(fun: self.session?.getCredentials, params: cred)
        return res
    }

    public func register(credentials: Credentials? = nil, hw: HWDevice? = nil) async throws {
        try await self.connect()
        let res = try self.session?.registerUser(details: credentials?.toDict() ?? [:], hw_device: ["device": hw?.toDict() ?? [:]])
        _ = try await resolve(res)
    }
    
    public func encryptWithPin(_ params: EncryptWithPinParams) async throws -> EncryptWithPinResult {
        return try await wrapperAsync(fun: self.session?.encryptWithPin, params: params)
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
    
    public func setWatchOnly(username: String, password: String) async throws {
        _ = try self.session?.setWatchOnly(username: username, password: password)
    }
    
    public func getWatchOnlyUsername() async throws -> String? {
        return try session?.getWatchOnlyUsername()
    }

    public func setCSVTime(value: Int) async throws {
        let res = try self.session?.setCSVTime(details: ["value": value])
        _ = try await resolve(res)
    }
    
    public func setTwoFactorLimit(details: [String: Any]) async throws {
        let res = try self.session?.setTwoFactorLimit(details: details)
        _ = try await resolve(res)
    }
    
    public func convertAmount(input: [String: Any]) throws -> [String: Any] {
        try self.session?.convertAmount(input: input) ?? [:]
    }
    
    public func refreshAssets(icons: Bool, assets: Bool, refresh: Bool) async throws {
        try self.session?.refreshAssets(params: ["icons": icons, "assets": assets, "refresh": refresh])
    }
    
    public func getReceiveAddress(subaccount: UInt32) async throws -> Address {
        let params = Address(address: nil, pointer: nil, branch: nil, subtype: nil, userPath: nil, subaccount: subaccount, addressType: nil, script: nil)
        let res: Address = try await wrapperAsync(fun: self.session?.getReceiveAddress, params: params)
        return res
    }
    
    public func getBalance(subaccount: UInt32, numConfs: Int) async throws -> [String: Int64] {
        let balance = try self.session?.getBalance(details: ["subaccount": subaccount, "num_confs": numConfs])
        let res = try await resolve(balance)
        return res?["result"] as? [String: Int64] ?? [:]
    }
    
    public func changeSettingsTwoFactor(method: TwoFactorType, config: TwoFactorConfigItem) async throws {
        let res = try self.session?.changeSettingsTwoFactor(method: method.rawValue, details: config.toDict() ?? [:])
        _ = try await resolve(res)
    }
    
    public func updateSubaccount(subaccount: UInt32, hidden: Bool) async throws {
        let res = try self.session?.updateSubaccount(details: ["subaccount": subaccount, "hidden": hidden])
        _ = try await resolve(res)
    }
    
    public func createSubaccount(_ details: CreateSubaccountParams) async throws -> WalletItem {
        let wallet: WalletItem = try await wrapperAsync(fun: self.session?.createSubaccount, params: details)
        wallet.network = self.gdkNetwork.network
        return wallet
    }

    public func renameSubaccount(subaccount: UInt32, newName: String) async throws {
        let res = try self.session?.updateSubaccount(details: ["subaccount": subaccount, "name": newName])
        _ = try await resolve(res)
    }

    public func changeSettings(settings: Settings) async throws -> Settings? {
        return try await wrapperAsync(fun: self.session?.changeSettings, params: settings)
    }

    public func getUnspentOutputsForPrivateKey(_ params: UnspentOutputsForPrivateKeyParams) async throws -> [String: Any]? {
        let utxos = try self.session?.getUnspentOutputsForPrivateKey(details: params.toDict()!)
        let res = try await resolve(utxos)
        let result = res?["result"] as? [String: Any]
        return result?["unspent_outputs"] as? [String: Any]
    }

    public func getUnspentOutputs(subaccount: UInt32, numConfs: Int) async throws -> [String: Any] {
        let utxos = try self.session?.getUnspentOutputs(details: ["subaccount": subaccount, "num_confs": numConfs])
        let res = try await resolve(utxos)
        let result = res?["result"] as? [String: Any]
        return result?["unspent_outputs"] as? [String: Any] ?? [:]
    }
    
    func wrapperTransaction(fun: GdkFunc?, tx: Transaction) async throws -> Transaction {
        if let fun = try fun?(tx.details) {
            let res = try await resolve(fun)
            let result = res?["result"] as? [String: Any]
            return Transaction(result ?? [:], subaccount: tx.subaccount)
        }
        throw GaError.GenericError()
    }

    public func createTransaction(tx: Transaction) async throws -> Transaction {
        try await wrapperTransaction(fun: self.session?.createTransaction, tx: tx)
    }

    public func blindTransaction(tx: Transaction) async throws -> Transaction {
        try await wrapperTransaction(fun: self.session?.blindTransaction, tx: tx)
    }

    public func signTransaction(tx: Transaction) async throws -> Transaction {
        try await wrapperTransaction(fun: self.session?.signTransaction, tx: tx)
    }

    public func sendTransaction(tx: Transaction) async throws -> SendTransactionSuccess {
        let fun = try self.session?.sendTransaction(details: tx.details)
        let res = try await resolve(fun)
        let result = res?["result"] as? [String: Any]
        if let res = SendTransactionSuccess.from(result ?? [:]) as? SendTransactionSuccess {
            return res
        }
        throw GaError.GenericError()
    }

    public func broadcastTransaction(txHex: String) async throws -> SendTransactionSuccess {
        if let txHash = try self.session?.broadcastTransaction(tx_hex: txHex) as? String {
            return SendTransactionSuccess(txHash: txHash)
        }
        throw GaError.GenericError()
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
        return try await wrapperAsync(fun: self.session?.getPreviousAddresses, params: params)
    }

    public func signMessage(_ params: SignMessageParams) async throws -> SignMessageResult? {
        return try await wrapperAsync(fun: self.session?.signMessage, params: params)
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

    public func discovery() async throws -> Bool {
        do {
            let subaccounts = try await self.subaccounts(true)
            if let first = subaccounts.filter({ $0.pointer == 0 }).first,
               first.isSinglesig && !(first.bip44Discovered ?? false) {
                _ = try await self.updateSubaccount(subaccount: 0, hidden: true)
            }
            return !subaccounts.filter({ $0.bip44Discovered ?? false }).isEmpty
        } catch { throw LoginError.connectionFailed() }
    }

    public func networkConnect() async {
        try? await reconnectionTasks.add {
            NSLog("tor_hint: async connect \(self.gdkNetwork.network)")
            try? self.session?.reconnectHint(hint: ["tor_hint": "connect", "hint": "connect"])
        }
    }

    public func networkDisconnect() async {
        paused = true
        try? await reconnectionTasks.add {
            NSLog("tor_hint: async disconnect \(self.gdkNetwork.network)")
            try? self.session?.reconnectHint(hint: ["tor_hint": "disconnect", "hint": "disconnect"])
        }
    }

    public func httpRequest(params: [String: Any]) -> [String: Any]? {
        return try? session?.httpRequest(params: params)
    }

    public func bcurEncode(params: BcurEncodeParams) async throws -> BcurEncodedData? {
        try await connect()
        return try await wrapperAsync(fun: self.session?.bcurEncode, params: params)
    }

    public func bcurDecode(params: BcurDecodeParams, bcurResolver: BcurResolver) async throws -> BcurDecodedData? {
        try await connect()
        return try await wrapperAsync(fun: self.session?.bcurDecode, params: params, bcurResolver: bcurResolver)
    }

    public func jadeBip8539Request() async -> (Data?, BcurEncodedData?) {
        let privateKey = createEcKey()
        let params = BcurEncodeParams(
            urType: "jade-bip8539-request",
            numWords: 12,
            index: 0,
            privateKey: privateKey?.hex
        )
        let data = try? await bcurEncode(params: params)
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
}
extension SessionManager {
    @MainActor
    public func newNotification(notification: [String: Any]?) {
        guard let notificationEvent = notification?["event"] as? String,
                let event = EventType(rawValue: notificationEvent),
                let data = notification?[event.rawValue] as? [String: Any] else {
            return
        }
        #if DEBUG
        NSLog("\(gdkNetwork.network) \(event): \(data)")
        #endif
        switch event {
        case .Block:
            guard let height = data["block_height"] as? UInt32 else { break }
            blockHeight = height
            if !paused {
                // avoid to refresh contents if session is not resumed yet
                post(event: .Block, userInfo: data)
            }
        case .Subaccount:
            let txEvent = SubaccountEvent.from(data) as? SubaccountEvent
            post(event: .Block, userInfo: data)
            post(event: .Transaction, userInfo: data)
        case .Transaction:
            post(event: .Transaction, userInfo: data)
            let txEvent = TransactionEvent.from(data) as? TransactionEvent
            if txEvent?.type == "incoming" {
                txEvent?.subAccounts.forEach { pointer in
                    post(event: .AddressChanged, userInfo: ["pointer": UInt32(pointer)])
                }
                DispatchQueue.main.async {
                    //DropAlert().success(message: NSLocalizedString("id_new_transaction", comment: ""))
                }
            }
        case .TwoFactorReset:
            Task { try? await loadTwoFactorConfig() }
            post(event: .TwoFactorReset, userInfo: data)
        case .Settings:
            settings = Settings.from(data)
            post(event: .Settings, userInfo: data)
        case .Network:
            guard let connection = Connection.from(data) as? Connection else { return }
            let hasElectrumUrl = !(getPersonalElectrumServer()?.isEmpty ?? true)
            if !logged && gdkNetwork.singlesig && hasElectrumUrl && connection.currentState == "disconnected" {
                let msg = "Your Personal Electrum Server for %@ can\'t be reached. Check your settings or your internet connection.".localized
                gdkFailures = [String(format: msg, gdkNetwork.chain)]
                return
            }
            // avoid handling notification for unlogged session
            guard connected && logged else { return }
            // notify disconnected network state
            if connection.currentState == "disconnected" {
                paused = true
                self.post(event: EventType.Network, userInfo: data)
                return
            }
            // Restore connection through hidden login
            Task {
                do {
                    NSLog("\(self.gdkNetwork.network) reconnect")
                    try await reconnect()
                    NSLog("\(self.gdkNetwork.network) reconnected")
                    paused = false
                    post(event: EventType.Network, userInfo: data)
                } catch {
                    NSLog("Error on reconnected: \(error.localizedDescription)")
                }
            }
        case .Tor:
            post(event: .Tor, userInfo: data)
        case .Ticker:
            post(event: .Ticker, userInfo: data)
        default:
            break
        }
    }

    public func getPersonalElectrumServer() -> String? {
        return session?.netParams["electrum_url"] as? String
    }

    @MainActor
    func post(event: EventType, object: Any? = nil, userInfo: [String: Any] = [:]) {
        var data = userInfo
        data["session_id"] = uuid.uuidString
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: event.rawValue),
                                        object: object, userInfo: data)
    }
}
