import Foundation
import LiquidWalletKit
import greenaddress 
import hw

public final class LwkNetworkBackend: NetworkBackend {

    public static let TIP_POLL_INTERVAL_MS: UInt64 = 10_000
    public static let AMP_SERVER_URL_TESTNET = "https://amp.enterprise.blockstream.com"
    public static let AMP_SERVER_KEYORIGIN_XPUB_TESTNET = "[b805d768/87h/1h/0h]tpubDCYEgnLyCH2okSittQNNB8JHLwPgmoEAoKcMrJDHP9dFVamsadPAFJQ77C1htgR8ksie3VksLXoryng9AUaPZSF8FwTwEv6CaHp8j2YCrds"
    public static let AMP_SERVER_URL_MAINNET = ""
    public static let AMP_SERVER_KEYORIGIN_XPUB_MAINNET = ""

    public let network: GdkNetwork
    public var accounts: [Account]
    public var block: Block?

    public var isConnected = false
    public var isLoggedIn = false
    public var isWatchOnly = false
    public var authenticationRequired = false
    public var logged: Bool { isLoggedIn }
    public var gdkNetwork: GdkNetwork { network }
    public var networkId: NetworkId { network.networkId }
    public var networkType: NetworkId { network.networkId }
    private var accountBackends = [String: AccountBackend]()

    private let dataDir: String
    private var signer: Signer?
    let lwkNetwork: LiquidWalletKit.Network
    private let client: LwkNetworkClient
    private var tipTask: Task<Void, Never>?
    private let isAmp = true
    private let amp2Server: Amp2?

    init(
        dataDir: String,
        network: GdkNetwork
    ) {
        self.dataDir = dataDir
        self.network = network
        self.lwkNetwork = network.testnet ? LiquidWalletKit.Network.testnet() : LiquidWalletKit.Network.mainnet()
        self.client = LwkNetworkClient(isTestnet: network.testnet)
        self.accounts = []
        self.amp2Server = try? LwkNetworkBackend.createAmp2Client(network)
    }

    func storage() throws -> KeychainStorage {
        guard let fingerprint = try signer?.fingerprint() else {
            throw GaError.GenericError("LWK signer not initialised; login first")
        }
        return KeychainStorage(account: fingerprint, service: "NetworkBackend")
    }

    func getAccounts() async throws -> [Account] {
        if var accounts: [Account] = try? storage().read()?.decode() {
            for a in accounts.enumerated() {
                accounts[a.offset].networkInjected = network
            }
            return accounts
        }
        return []
    }

    private func loginUser(
        credentials: Credentials
    ) async throws {
        guard let mnemonicString = credentials.mnemonic else {
            throw GaError.GenericError("missing mnemonic")
        }
        let localSigner = try Signer(
            mnemonic: Mnemonic(s: mnemonicString),
            network: lwkNetwork
        )
        self.signer = localSigner
        self.isLoggedIn = true
        self.accounts = try await getAccounts()
        print("LWK login complete for \(network.networkId)")
        blockHeaderPolling()
        try await syncSwallowing()
    }

    public func login(
        credentials: Credentials)
    async throws -> LoginUserResult? {
        guard credentials.mnemonic != nil else {
            // disable for hardware wallet
            return nil
        }
        try await loginUser(
                credentials: credentials
            )
        let walletId = try Gdk
            .getWalletIdentifier(
                gdkNetwork: NetworkId.electrumMainnet.network,
                credentials: credentials
            )
        return LoginUserResult(
            xpubHashId: walletId.xpubHashId,
            walletHashId: walletId.walletHashId
        )
    }

    private func blockHeaderPolling() {
        guard tipTask == nil else { return }
        tipTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }

                do {
                    let header = try await self.client.tip()

                    // Emulating updateBlock logic safely inside main target loop properties
                    let block = Block(
                        hash: header.blockHash(),
                        height: header.height(),
                        timestamp: Int64(header.time())
                    )
                    print("Update block \(block)")
                    self.block = block
                    try await self.scanBlockchain()
                } catch is CancellationError {
                    break
                } catch {
                    print("LWK tip poll failed: \(error.localizedDescription)")
                }

                do {
                    try await Task.sleep(nanoseconds: Self.TIP_POLL_INTERVAL_MS * 1_000_000)
                } catch {
                    break
                }
            }
        }
    }

    private func scanBlockchain() async throws {
        // Gathering backends safely via native iteration structures
        // Note: accountBackends tracking maps via custom ThreadSafeDictionary built in NetworkBackend
        for account in accounts {
            let backend = try accountBackend(account)
            if let lwkBackend = backend as? LwkAccountBackend {
                if let update = try await client.fullScanToIndex(wollet: lwkBackend.wollet) {
                    print(
                        "Update for \(account.id) : \(try update.serialize().toHex())"
                    )
                    try lwkBackend.wollet.applyUpdate(update: update)
                }
            }
        }
    }

    private func syncSwallowing() async throws {
        do {
            try await sync()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            print("LWK sync on login failed: \(error.localizedDescription)")
        }
    }

    public func accountBackend(_ account: Account) throws -> AccountBackend {
        if let accountBackend = accountBackends[account.id] {
            return accountBackend
        } else {
            let accountBackend = try createAccountBackend(account: account)
            accountBackends[account.id] = accountBackend
            return accountBackend
        }
    }

    static func createAmp2Client(_ network: GdkNetwork) throws -> Amp2 {
        return try Amp2(
            serverKey: network.testnet ? LwkNetworkBackend.AMP_SERVER_KEYORIGIN_XPUB_TESTNET : LwkNetworkBackend.AMP_SERVER_KEYORIGIN_XPUB_MAINNET,
            url: network.testnet ? LwkNetworkBackend.AMP_SERVER_URL_TESTNET : LwkNetworkBackend.AMP_SERVER_URL_MAINNET
        )
    }

    func extractSlip77(from input: String) throws -> String {
        let regex = /slip77\((.*?)\)/
        if let match = input.firstMatch(of: regex) {
            return String(match.output.1)
        }
        throw GaError.GenericError("Invalid slip77")
    }

    func lwkPointer(type: AccountType) throws -> UInt32 {
        switch type {
        case .bip84Segwit:
            return 0
        case .bip49SegwitWrapped:
            return 1
        case .amp2Account:
            return 2
        default:
            throw GaError.GenericError("Unsupported LWK account type: \(type)")
        }
    }

    func amp2Descriptor() throws -> Amp2Descriptor {
        guard let signer else {
            throw GaError.GenericError("Invalid wallet or signer")
        }
        guard let amp2Server else {
            throw GaError.GenericError("Invalid amp2 server")
        }
        let userXpub = try signer.keyoriginXpub(bip: .newBip87())
        let descriptor = try signer.wpkhSlip77Descriptor()
        let descriptorBlindingKey = try extractSlip77(
            from: descriptor.description
        )
        return try amp2Server
            .descriptorFromStr(
                keyoriginXpub: userXpub,
                descriptorBlindingKey: descriptorBlindingKey
            )
    }

    public func createAccount(params: CreateSubaccountParams) async throws -> Account {
        guard params.type == .amp2Account else {
            throw GaError.GenericError("Unsupported LWK account type: \(params.type)")
        }
        guard let amp2Server else {
            throw GaError.GenericError("Invalid amp2 server")
        }
        let amp2Descriptor = try amp2Descriptor()
        var wId: String?
        if params.type == AccountType.amp2Account {
            wId = try amp2Server.registerWallet(desc: amp2Descriptor)
            logger.info("Registered AMP2 wallet \(wId ?? "")")
        }
        let account = Account(
            gdkName: params.name,
            pointer: try lwkPointer(type: params.type),
            receivingId: wId,
            type: params.type,
            coreDescriptors: [amp2Descriptor.descriptor().description],
            networkInjected: network)
        try await updateAccount(account: account)
        let accountBackend = try createAccountBackend(account: account)
        accounts = [account]
        accountBackends[account.id] = accountBackend
        return account
    }

    public func createAccountBackend(account: Account) throws -> AccountBackend {
        guard let signer, account.type == .amp2Account, let descriptor = account.coreDescriptors?.first else {
           throw GaError.GenericError("Invalid wallet or signer")
        }
        let datadir = "\(dataDir)/lwk/\(network.network)/0"
        let wolletBuilder = WolletBuilder(
            network: lwkNetwork,
            descriptor: try WolletDescriptor(descriptor: descriptor))
        try wolletBuilder.withLegacyFsStore(datadir: datadir)
        let wollet = try wolletBuilder.build()
        return LwkAccountBackend(
            networkBackend: self,
            wollet: wollet,
            signer: signer,
            account: account,
            amp2: amp2Server
        )
    }

    public func broadcastTransaction(broadcastTransaction: BroadcastTransactionParams) async throws -> SendTransactionSuccess {
        guard let txString = broadcastTransaction.transaction else {
            throw GaError.GenericError("Transaction is required")
        }
        let tx = try LiquidWalletKit.Transaction(hex: txString)
        let res = try await client
            .broadcast(
                tx: tx
            )
        return SendTransactionSuccess(
            txHash: res.description.description,
            transaction: txString
        )
    }

    public func sync() async throws {
        guard isLoggedIn else { return }
        // Sync implementation logic
    }

    public func disconnect() async {
        isConnected = false
        isLoggedIn = false
        signer = nil
        accountBackends.removeAll()
        tipTask?.cancel()
        tipTask = nil
    }

    public func isPolicyAsset(assetId: String?) -> Bool {
        if network.liquid {
            return network.policyAsset == assetId
        } else {
            return assetId == nil || assetId == AssetInfo.btcId
        }
    }

    public func connect(params: ConnectionParams) async throws {
        // noop
    }

    public func isAddressValid(address: String) async throws -> Bool {
        throw GaError.GenericError("Not implemented")
    }

    public func getAccounts(refresh: Bool) async throws -> [Account] {
        guard isLoggedIn else { return [] }
        return accounts
    }

    public func getAccount(account: Account) async throws -> Account {
        accounts.filter { $0.id == account.id }.first!
    }

    public func updateAccount(account: Account, name: String? = nil, hidden: Bool? = nil) async throws {
        var account = account
        account.gdkName = name ?? account.gdkName
        account.hidden = hidden ?? account.hidden
        let storage = try storage()
        try storage.write(try [account].encoded())
        self.accounts = [account]
    }
}
