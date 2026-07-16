import Foundation
import UIKit
import greenaddress
import hw
import lightning
import LiquidWalletKit

public class WalletManager {

    // Return current WalletManager used for the active user session
    public static var current: WalletManager? {
        if let account = WalletsStorage.shared.current {
            return WalletsRepository.shared.get(for: account.id)
        }
        return nil
    }

    // Swap Monitor
    public var swapMonitor: SwapMonitor?

    // Registry asset manager
    public var registry: AssetsManager

    // Converter service
    public var converter: ConverterManager?

    // Lwk boltz session
    public var lwkBoltzBackend: LwkBoltzBackend?
    public var deferredLwkLoginTask: Task<Void, Error>?

    // Event Delegate NewNotificationDelegate
    public weak var newNotificationDelegate: NewNotificationDelegate?

    // Hashmap of available networks with open session
    public var networkBackends = [NetworkId: NetworkBackend]()

    // Prominent network used for login with stored credentials and settings
    public private(set) var prominentNetworkId: NetworkId
    public var defaultNetwork: GdkNetwork { prominentNetwork }
    public var prominentNetwork: GdkNetwork {
        prominentNetworkId.gdkNetwork
    }
    public var prominentNetworkBackend: GdkNetworkBackend {
        gdkNetworkBackend(prominentNetworkId)
    }
    public var prominentSession: SessionManager {
        gdkNetworkBackend(prominentNetworkId).session
    }

    public var mainnet: Bool { prominentNetwork.mainnet}
    public var testnet: Bool { !prominentNetwork.mainnet}
    public var connected: Bool { prominentNetworkBackend.isConnected }
    public var logged: Bool { prominentNetworkBackend.isLoggedIn }

    // Cached list of subaccounts and balances
    public var allAccounts: [Account] {
        networkBackends.values.flatMap(\.accounts)
    }
    public var accounts: [Account] { allAccounts.filter { !$0.hidden } }

    // Variables
    public var failureSessionsError = Failures()
    public var isWatchonly: Bool = false
    public var isEphemeral: Bool = false
    public var isHW: Bool { hwDevice != nil }
    public var isJade: Bool { hwDevice?.isJade ?? false }
    public var isLedger: Bool { hwDevice?.isLedger ?? false }
    public var hwDevice: HWDevice?
    public var updatedRegistryAt: Double?

    // Resolvers
    public var popupResolver: PopupResolverDelegate?
    public var hwProtocol: HWProtocol?
    public var hwInterfaceResolver: HwInterfaceResolver?

    // Constructor
    public init(
        networkId: NetworkId
    ) {
        self.prominentNetworkId = networkId
        self.registry = AssetsManager(
            testnet: networkId.testnet,
            lightning: true
        )
        self.converter = ConverterManager(
            provider: self,
            testnet: networkId.testnet
        )
        initNetworkBackends()

        lwkBoltzBackend = LwkBoltzBackend(
            network: networkId.testnet ? Network.testnet() : Network.mainnet()
        )
    }

    public func hasActiveNetwork(_ network: GdkNetwork) -> Bool {
        hasActiveNetwork(network.networkId)
    }

    public func hasActiveNetwork(_ networkId: NetworkId) -> Bool {
        let backend = networkBackend(networkId)
        return activeNetworkIds.contains(networkId) && backend.isLoggedIn
    }

    public var loggedInGdkNetworkBackends: [NetworkId: GdkNetworkBackend] {
        networkBackends
            .filter { ($0.value as? GdkNetworkBackend) != nil }
            .filter { $0.value.isLoggedIn }
            .reduce(into: [NetworkId: GdkNetworkBackend]()) { result, element in
                let network = element.key
                result[network] = gdkNetworkBackend(network)
            }
    }

    public var loggedInNetworkBackends: [NetworkId: NetworkBackend] {
        networkBackends
            .filter { $0.value.isLoggedIn }
            .reduce(into: [NetworkId: NetworkBackend]()) { result, element in
                let network = element.key
                result[network] = networkBackend(network)
            }
    }

    public var connectedNetworkBackends: [NetworkId: NetworkBackend] {
        networkBackends.filter { $0.value.isConnected }
    }
    public var connectedGdkNetworkBackends: [NetworkId: GdkNetworkBackend] {
        networkBackends
            .filter { ($0.value as? GdkNetworkBackend) != nil }
            .filter { $0.value.isConnected }
            .reduce(into: [NetworkId: GdkNetworkBackend]()) { result, element in
                let network = element.key
                result[network] = gdkNetworkBackend(network)
            }
    }

    public var activeNetworkIds: Set<NetworkId> {
        let pairs = networkBackends.compactMap { (key, value) -> NetworkId? in
            if value.isConnected { return key }
            return nil
        }
        return Set(pairs)
    }

    public var hasLightning: Bool { glNetworkBackend()?.isLoggedIn ?? false }
    public var hasLwkAmp: Bool {
        lwkNetworkBackend(testnet ? .lwkTestnet : .lwkMainnet)?.isLoggedIn ?? false
    }
    public var hasLwkSwap: Bool { lwkBoltzBackend?.logged == true }
    public var hasAmpAccount: Bool {
        accounts
            .first(
                where: { $0.type == .ampAccount || $0.type == .amp2Account
                }) != nil
    }

    public func createAccount(
        network: GdkNetwork,
        params: CreateSubaccountParams,
    ) async throws -> Account {
        let backend = gdkNetworkBackend(network.networkId)
        let res = try await backend.createAccount(params: params)
        // Update account list
        _ = try await updateAccounts()
        return res
    }

    public func updateAccount(
        account: Account,
        isHidden: Bool? = nil,
        newAccountName: String? = nil
    ) async throws -> Account {
        // Disable account editing for lightning accounts
        if account.isLightning { return account }
        if account.isLwk { return account }

        try await gdkAccountBackend(account).updateAccount(
            name: newAccountName,
            hidden: isHidden)
        _ = try await updateAccounts()
        return try await gdkNetworkBackend(account.networkId)
            .getAccount(account: account)
    }

    public func getAccounts(refresh: Bool = false) async throws -> [Account] {
        var accounts = [Account]()
        for backend in loggedInNetworkBackends.values {
            let backendAccounts = try await backend.getAccounts(refresh: refresh)
            accounts += backendAccounts
        }
        return accounts.sorted()
    }

    public func getAccounts(network: GdkNetwork, refresh: Bool = false) async throws -> [Account] {
        try await networkBackend(network.networkId)
            .getAccounts(refresh: refresh)
    }

    public func getAccount(account: Account) async throws -> Account? {
        return try await gdkNetworkBackend(account.networkId)
            .getAccount(account: account)
    }

    func updateAccounts(refresh: Bool = false) async throws -> [Account] {
        return try await getAccounts(refresh: refresh)
    }

    public func disconnect() async {
        deferredLwkLoginTask?.cancel()
        deferredLwkLoginTask = nil
        lwkBoltzBackend?.disconnect()
        lwkBoltzBackend = nil
        for backend in networkBackends.values {
            try? await backend.disconnect()
        }
        networkBackends.removeAll()
    }

    private func initNetworkBackends(initNetworks: [NetworkId]? = nil) {
        let targets = initNetworks ?? networks()
        for target in targets where networkBackends[target] == nil {
            switch target {
            case .lwkMainnet, .lwkTestnet:
                let datadir = Gdk.shared.config.datadir ?? URL.applicationSupportDirectory.path()
                networkBackends[target] = LwkNetworkBackend(
                    dataDir: datadir,
                    network: target.gdkNetwork
                )
            case .lightningMainnet:
                networkBackends[target] = GlNetworkBackend(
                    network: target.gdkNetwork,
                    newNotificationDelegate: self
                )
            default:
                networkBackends[target] = GdkNetworkBackend(
                    network: target.gdkNetwork,
                    popupResolver: popupResolver,
                    hwProtocol: hwProtocol,
                    hwInterfaceResolver: hwInterfaceResolver,
                    newNotificationDelegate: self
                )
            }
        }
    }

    // Get Account Backend

    public func accountBackend(_ account: Account) -> AccountBackend {
        networkBackend(account.networkId)
            .accountBackend(account)
    }
    public func gdkAccountBackend(_ account: Account) -> GdkAccountBackend {
        guard let accountBackend = accountBackend(account) as? GdkAccountBackend else {
            fatalError(
                "Missing gdk account backend for \(account.networkId.network) \(account.pointer)"
            )
        }
        return accountBackend
    }
    public func glAccountBackend(_ account: Account) -> GlAccountBackend {
        guard let accountBackend = accountBackend(account) as? GlAccountBackend else {
            fatalError(
                "Missing gl account backend for \(account.networkId.network) \(account.pointer)"
            )
        }
        return accountBackend
    }
    public func lwAccountBackend(_ account: Account) -> LwkAccountBackend {
        guard let accountBackend = accountBackend(account) as? LwkAccountBackend else {
            fatalError(
                "Missing lwk account backend for \(account.networkId.network) \(account.pointer)"
            )
        }
        return accountBackend
    }

    // Get Network Backend

    public func networkBackend(_ network: NetworkId) -> NetworkBackend {
        guard let backend = networkBackends[network] else {
            fatalError("Missing backend for \(network.network)")
        }
        return backend
    }

    public func gdkNetworkBackend(_ network: NetworkId) -> GdkNetworkBackend {
        guard let backend = networkBackend(network) as? GdkNetworkBackend else {
            fatalError("Gdk missing backend for \(network.network)")
        }
        return backend
    }

    public func glNetworkBackend() -> GlNetworkBackend? {
        guard networkBackends.keys.contains(.lightningMainnet) else {
            return nil
        }
        return networkBackend(.lightningMainnet) as? GlNetworkBackend
    }

    public func lwkNetworkBackend(_ network: NetworkId) -> LwkNetworkBackend? {
        guard networkBackends.keys.contains(network) else {
            return nil
        }
        return networkBackend(network) as? LwkNetworkBackend
    }

    // Get Session Manager

    public func getGdkSession(for network: NetworkId) -> SessionManager {
        gdkNetworkBackend(network).session
    }
    public func getGdkSession(for account: Account) -> SessionManager {
        gdkAccountBackend(account).session
    }

    public func getGlSession() -> LightningSessionManager? {
        glNetworkBackend()?.session
    }

    public var lightningSession: LightningSessionManager? {
        glNetworkBackend()?.session
    }

    public func awaitLwkSession() async -> LwkBoltzBackend? {
        if let task = deferredLwkLoginTask {
            _ = try? await task.value
        }
        return lwkBoltzBackend
    }

    public var hasMultisig: Bool {
        loggedInGdkNetworkBackends.keys.filter { $0.multisig }.count > 0
    }
    public var hasLiquidMultisig: Bool {
        loggedInGdkNetworkBackends.keys
            .filter { $0.multisig && $0.liquid }.count > 0
    }
    public var hasBTCMultisig: Bool {
        loggedInGdkNetworkBackends.keys
            .filter { $0.multisig && $0.bitcoin }.count > 0
    }

    // Get Network Id

    public var bitcoinSinglesigNetworkId: NetworkId {
        mainnet ? .electrumMainnet : .electrumTestnet
    }
    public var liquidSinglesigNetworkId: NetworkId {
        mainnet ? .electrumLiquid : .electrumTestnetLiquid
    }
    public var lwkNetworkId: NetworkId {
        mainnet ? .lwkMainnet : .lwkTestnet
    }
    public var singlesigNetworkIds: [NetworkId] { [bitcoinSinglesigNetworkId] + [liquidSinglesigNetworkId] }
    public var bitcoinMultisigNetworkId: NetworkId {
        mainnet ? .greenMainnet : .greenTestnet
    }
    public var liquidMultisigNetworkId: NetworkId {
        mainnet ? .greenLiquid : .greenTestnetLiquid
    }
    public var multisigNetworkIds: [NetworkId] { [bitcoinMultisigNetworkId] + [liquidMultisigNetworkId] }
    public var bitcoinNetworkIds: [NetworkId] { [bitcoinSinglesigNetworkId] + [bitcoinMultisigNetworkId] }
    public var liquidNetworkIds: [NetworkId] { [liquidSinglesigNetworkId] + [liquidMultisigNetworkId] + [lwkNetworkId]}

    // Get Network Backend

    public var liquidSinglesigBackend: GdkNetworkBackend {
        gdkNetworkBackend(liquidSinglesigNetworkId)
    }
    public var bitcoinSinglesigBackend: GdkNetworkBackend {
        gdkNetworkBackend(bitcoinSinglesigNetworkId)
    }
    public var liquidMultisigBackend: GdkNetworkBackend {
        gdkNetworkBackend(liquidMultisigNetworkId)
    }
    public var bitcoinMultisigBackend: GdkNetworkBackend {
        gdkNetworkBackend(bitcoinMultisigNetworkId)
    }

    public var lwkBackend: LwkNetworkBackend? {
        lwkNetworkBackend(lwkNetworkId)
    }

    // Active backends
    public var activeBitcoinBackends: [NetworkBackend] {
        bitcoinNetworkIds
            .compactMap { networkBackend($0)}
            .filter { $0.isLoggedIn }
    }
    public var activeLiquidBackends: [NetworkBackend] {
        liquidNetworkIds
            .compactMap { networkBackend($0)}
            .filter { $0.isLoggedIn }
    }
    public var activeSinglesigBackends: [GdkNetworkBackend] {
        singlesigNetworkIds
            .compactMap { gdkNetworkBackend($0)}
            .filter { $0.isLoggedIn }
    }
    public var activeMultisigBackends: [GdkNetworkBackend] {
        multisigNetworkIds
            .compactMap { gdkNetworkBackend($0)}
            .filter { $0.isLoggedIn }
    }
    public var activeNetworkBackends: [GdkNetworkBackend] {
        networks()
            .compactMap { gdkNetworkBackend($0)}
            .filter { $0.isLoggedIn }
    }

    // Active networks Id
    public var activeLiquidNetworkIds: [NetworkId] {
        activeLiquidBackends.map { $0.networkId }
    }
    public var activeBitcoinNetworkIds: [NetworkId] {
        activeBitcoinBackends.map { $0.networkId }
    }
    public var activeSinglesigNetworkIds: [NetworkId] {
        activeSinglesigBackends.map { $0.networkId }
    }
    public var activeMultisigNetworkIds: [NetworkId] {
        activeMultisigBackends.map { $0.networkId }
    }
    // List of accounts for networks / types
    public var bitcoinSubaccounts: [Account] {
        accounts.filter { bitcoinNetworkIds.contains($0.networkId) }
    }
    public var liquidSubaccounts: [Account] {
        accounts.filter { liquidNetworkIds.contains($0.networkId) }
    }
    public var lightningSubaccounts: [Account] {
        accounts.filter { $0.type == .lightning }
    }
    public var liquidAmpSubaccounts: [Account] {
        liquidSubaccounts.filter { $0.type == .ampAccount || $0.type == .amp2Account }
    }
    // List of accounts with funds
    public func subaccountsFor(assetId: String) -> [Account] {
        switch assetId {
        case AssetInfo.lightningId:
            return lightningSubaccounts
        case AssetInfo.btcId:
            return bitcoinSubaccounts
        default:
            if getAsset(assetId).amp ?? false {
                return liquidAmpSubaccounts
            } else {
                return liquidSubaccounts
            }
        }
    }
    public func subaccountsWithFunds(assetId: String) -> [Account] {
        (bitcoinSubaccounts + lightningSubaccounts + liquidSubaccounts)
            .filter {
                accountBackend($0).assets
                    .filter { $0.key == assetId }
                    .compactMap { $0.value }
                    .reduce(0, +) > 0
            }
    }
    public func bitcoinSubaccountsWithFunds() -> [Account] {
        bitcoinSubaccounts
            .filter {
                accountBackend($0).assets
                    .compactMap{ $0.value }
                    .reduce(0, +) > 0
            }
    }
    public func liquidSubaccountsWithFunds() -> [Account] {
        liquidSubaccounts
            .filter {
                accountBackend($0).assets
                    .compactMap{ $0.value }
                    .reduce(0, +) > 0
            }
    }

    public func liquidSubaccountsWithAssetIdFunds(assetId: String) -> [Account] {
        liquidSubaccounts
            .filter {
                accountBackend($0).assets
                    .filter { $0.key == assetId }
                    .compactMap { $0.value }
                    .reduce(0, +) > 0
            }
    }

    public func settings(for network: NetworkId? = nil) -> Settings? {
        let targetNet = network ?? prominentNetworkId
        return gdkNetworkBackend(targetNet).session.settings
    }

    public func twoFactorConfig(for network: NetworkId? = nil) -> TwoFactorConfig? {
        let targetNet = network ?? prominentNetworkId
        return gdkNetworkBackend(targetNet).session.twoFactorConfig
    }

    public func twoFactorReset(for network: NetworkId? = nil) -> TwoFactorReset? {
        let targetNet = network ?? prominentNetworkId
        return gdkNetworkBackend(
            targetNet
        ).session.twoFactorConfig?.twofactorReset
    }

    func syncSettings(restore: Bool) async throws {
        // Prefer Multisig for initial sync as those networks are synced across devices
        var backend = prominentNetworkBackend
        if restore {
            let networkBackend = loggedInGdkNetworkBackends
                .filter { $0.key.multisig }.values.first
            if let networkBackend = networkBackend {
                backend = networkBackend
            }
        }
        let settings = try await backend.session.loadSettings()
        for b in loggedInGdkNetworkBackends where b.key != backend.networkId && settings != b.value.session.settings {
            _ = try? await b.value.session
                .changeSettings(settings: settings!)
            _ = try? await b.value.session.loadSettings()
        }
    }

    public func getSystemMessages() async throws -> [SystemMessage] {
        var systemMessages = [SystemMessage]()
        for backend in loggedInGdkNetworkBackends.values {
            let text = try? await backend.session.loadSystemMessage()
            systemMessages += [SystemMessage(
                text: text ?? "",
                network: backend.network.network
            )]
        }
        return systemMessages
    }

    public func subaccountUpdate(account: Account) async throws -> Account? {
        return try await updateAccount(
            account: account,
            isHidden: account.hidden
        )
    }

    public func balances(subaccounts: [Account]) async throws -> [String: [String: Int64]] {
        var balances: [String: [String: Int64]] = [:]
        for account in subaccounts {
            let amounts = try await accountBackend(account).getBalance(confirmations: 0)
            balances[account.id] = amounts
        }
        return balances
    }

    public func transactions(subaccounts: [Account], first: Int = 0, count: Int = 30) async throws -> [Transaction] {
        var txs: [Transaction] = []
        for account in subaccounts {
            let params = GetTransactionsParams(
                subaccount: account.pointer,
                first: first, count: count
            )
            let gdkTxs = try await accountBackend(account).getTransactions(
                params: params
            )
            txs += gdkTxs.list.map { Transaction($0.details, accountId: account.id) }
        }
        return txs.sorted()
    }

    public func pagedTransactions(subaccounts: [Account], of page: Int = 0) async throws -> [String: Transactions] {
        var txs: [String: Transactions] = [:]
        for account in subaccounts {
            let params = GetTransactionsParams(
                subaccount: account.pointer,
                first: page * 30, count: 30
            )
            let gdkTxs = try await accountBackend(account)
                .getTransactions(params: params)
                .list
                .map { Transaction($0.details, accountId: account.id) }
            txs[account.id] = Transactions(list: gdkTxs)
        }
        return txs
    }

    func allBySubaccount(_ subaccount: Account) async throws -> [Transaction] {
        let offset = 30
        var page = 0
        var end: Bool = false
        var transactions: [Transaction] = []
        while end == false {
            let params = GetTransactionsParams(
                subaccount: subaccount.pointer,
                first: page * 30, count: 30
            )
            let gdkTxs = try await accountBackend(subaccount)
                .getTransactions(params: params)
                .list
                .map { Transaction($0.details, accountId: subaccount.id) }
            transactions.append(contentsOf: gdkTxs)
            if gdkTxs.count < offset {
                end = true
            } else {
                page += 1
            }
        }
        return transactions
    }
    public func allTransactions(subaccounts: [Account]) async throws -> [Transaction] {
        var txs: [Transaction] = []
        for account in subaccounts {
            let gdkTxs = try await self.allBySubaccount(account)
            txs += gdkTxs
        }
        return txs.sorted(by: { $0 > $1 })
    }

    public func bitcoinBlockHeight() -> UInt32? {
        return 0
    }

    public func liquidBlockHeight() -> UInt32? {
        return 0
    }

    public func pause() async {
        logger.info("WM pause networkDisconnect")
        for backend in connectedGdkNetworkBackends.values {
            try? await backend.session.disconnectHint()
        }
    }
    public func resume() async {
        logger.info("WM resume networkConnect")
        for backend in connectedGdkNetworkBackends.values {
            try? await backend.session.connectHint()
        }
    }

    public func isPaused() -> Bool {
        connectedGdkNetworkBackends.count != loggedInNetworkBackends.count
    }

    public func bcurEncode(params: BcurEncodeParams) async throws -> BcurEncodedData? {
        try await prominentNetworkBackend.session.bcurEncode(params: params)
    }

    public func bcurDecode(params: BcurDecodeParams, bcurResolver: BcurResolver) async throws -> BcurDecodedData? {
        try await prominentNetworkBackend.session.bcurDecode(params: params, bcurResolver: bcurResolver)
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
        try await prominentNetworkBackend.session.getPsbt(tx: tx)
    }

    public func psbtGetDetails(params: PsbtGetDetailParams) async throws -> Transaction {
        return try await prominentNetworkBackend.session.psbtGetDetails(params: params)
    }

    public func createRedepositTransaction(params: CreateRedepositTransactionParams) async throws -> Transaction {
        try await prominentNetworkBackend.session
            .createRedepositTransaction(params: params)
    }

    public func getExpiredSubaccounts() async throws -> [Account] {
        var expiredSubaccounts = [Account]()
        for subaccount in accounts.filter({$0.type == .standard}) {
            let networkBackend = gdkNetworkBackend(subaccount.networkId)
            let accountBackend = gdkAccountBackend(subaccount)
            let res = try await accountBackend.getUnspentOutputs(
                isBump: false,
                isExpired: true,
                expiredAt: 0//UInt64(networkBackend.block?.height ?? 0)
            )
            for assetUtxos in res {
                if assetUtxos.value.count > 0 {
                    if !expiredSubaccounts.contains(subaccount) {
                        expiredSubaccounts += [subaccount]
                    }
                }
            }
        }
        return expiredSubaccounts
    }

    public func selectableAssets() -> [String]? {
        let hasSubaccountAmp = !accounts.filter(
            { $0.type == .ampAccount || $0.type == .amp2Account
            }).isEmpty
        let hasLightning = !accounts.filter({ $0.networkId.lightning }).isEmpty
        let hasLiquid = !accounts.filter({ $0.networkId.liquid }).isEmpty
        let hasBitcoin = !accounts.filter({ $0.networkId.bitcoin }).isEmpty
        let assetIds = WalletManager.current?.registry.all
            .filter { !(!hasSubaccountAmp && $0.amp == true) }
            .filter { hasLightning || $0.assetId != AssetInfo.lightningId }
            .filter { hasBitcoin || ![AssetInfo.btcId, AssetInfo.testId].contains($0.assetId) }
            .filter { hasLiquid || [AssetInfo.btcId, AssetInfo.testId, AssetInfo.lightningId].contains($0.assetId) }
            .map { $0.assetId }
        return assetIds
    }
    public func deriveBoltzCredentials(from credentials: Credentials) throws -> Credentials {
        guard let mnemonic = credentials.mnemonic else {
            throw GaError.GenericError("No such mnemonic")
        }
        let bip85Key = Wally.bip85FromMnemonic(
            mnemonic: mnemonic,
            passphrase: credentials.bip39Passphrase,
            isTestnet: false,
            index: LwkBoltzBackend.BOLTZ_BIP85_INDEX)
        return Credentials(
            mnemonic: bip85Key,
            bip39Passphrase: credentials.bip39Passphrase)
    }
    public func deriveLightningCredentials(from credentials: Credentials) throws -> Credentials {
        guard let mnemonic = credentials.mnemonic else {
            throw GaError.GenericError("No such mnemonic")
        }
        let bip85Key = Wally.bip85FromMnemonic(
            mnemonic: mnemonic,
            passphrase: credentials.bip39Passphrase,
            isTestnet: false,
            index: 0)
        return Credentials(
            mnemonic: bip85Key,
            bip39Passphrase: credentials.bip39Passphrase)
    }

    public func getWalletIdentifier(
        network: GdkNetwork? = nil,
        credentials: Credentials,
    ) async throws -> WalletIdentifier? {
        let connParams = createConnectionParams(
            network: network ?? prominentNetwork
        )
        return try prominentNetworkBackend.session
            .getWalletIdentifier(netParams: connParams, credentials: credentials)
    }

    public func createConnectionParams(network: GdkNetwork) -> ConnectionParams {
        let applicationSettings = GdkSettings.read()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? CVarArg ?? ""
        let electrumUrl: String? = {
            if let srv = applicationSettings?.btcElectrumSrv, network.mainnet && !network.liquid && !srv.isEmpty {
                return srv
            } else if let srv = applicationSettings?.testnetElectrumSrv, !network.mainnet && !network.liquid && !srv.isEmpty {
                return srv
            } else if let srv = applicationSettings?.liquidElectrumSrv, network.mainnet && network.liquid && !srv.isEmpty {
                return srv
            } else if let srv = applicationSettings?.liquidTestnetElectrumSrv, !network.mainnet && network.liquid && !srv.isEmpty {
                return srv
            } else {
                return nil
            }
        }()
        let isDefaultEletrumEndpoint = [
            GdkSettings.btcElectrumSrvDefaultEndPoint,
            GdkSettings.liquidElectrumSrvDefaultEndPoint,
            GdkSettings.testnetElectrumSrvDefaultEndPoint,
            GdkSettings.liquidTestnetElectrumSrvDefaultEndPoint,
            "", nil].contains(electrumUrl)
        let electrumTls = isDefaultEletrumEndpoint ? nil : applicationSettings?.electrumTls
        let proxyURI = String(format: "socks5://%@:%@/", applicationSettings?.socks5Hostname ?? "", applicationSettings?.socks5Port ?? "")
        let gapLimit: Int? = network.singlesig ? applicationSettings?.gapLimit : nil
        return ConnectionParams(
            name: network.network,
            useTor: applicationSettings?.tor,
            proxy: proxyURI,
            userAgent: String(format: "green_ios_%@", version),
            electrumUrl: applicationSettings?.personalNodeEnabled ?? false ? electrumUrl : nil,
            electrumOnionUrl: applicationSettings?.personalNodeEnabled ?? false ? electrumUrl : nil,
            electrumTls: applicationSettings?.personalNodeEnabled ?? false ? electrumTls : nil,
            gapLimit: gapLimit
        )
    }
    public func networks() -> [NetworkId] {
        if prominentNetwork.mainnet {
            return [
                .electrumMainnet,
                .greenMainnet,
                .electrumLiquid,
                .greenLiquid,
                .lightningMainnet,
                //.lwkMainnet
            ]
        } else {
            return [
                .electrumTestnet,
                .greenTestnet,
                .electrumTestnetLiquid,
                .greenTestnetLiquid,
                .lwkTestnet
            ]
        }
    }
}

// Login functions

extension WalletManager {


    public func loginWatchonly(
        credentials: Credentials,
        lightningCredentials: Credentials? = nil,
        boltzCredentials: Credentials? = nil,
        parentWalletId: WalletIdentifier? = nil
    ) async throws -> LoginUserResult? {
        var loginUserResult: LoginUserResult?
        // login singlesig bitcoin
        let descriptors = credentials.coreDescriptors?.filter(
            { Wally.isDescriptor($0, for: NetworkId.electrumMainnet)
            })
        let slip132Keys = credentials.slip132ExtendedPubkeys?.filter({ Wally.isPubKey($0, for: NetworkId.electrumMainnet) })
        if !(descriptors ?? []).isEmpty || !(slip132Keys ?? []).isEmpty {
            let credentials = Credentials(coreDescriptors: descriptors, slip132ExtendedPubkeys: slip132Keys)
            let backend = gdkNetworkBackend(.electrumMainnet)
            let connParams = createConnectionParams(network: backend.network)
            try await backend.connect(params: connParams)
            loginUserResult = try await backend
                .login(credentials: credentials, device: nil)
        }
        // login singlesig liquid
        if let descriptors = credentials.coreDescriptors?.filter({ Wally.isDescriptor($0, for: .electrumLiquid) }), descriptors.count > 0 {
            let credentials = Credentials(coreDescriptors: descriptors)
            let backend = gdkNetworkBackend(.electrumLiquid)
            let connParams = createConnectionParams(network: backend.network)
            try await backend.connect(params: connParams)
            loginUserResult = try await backend
                .login(credentials: credentials, device: nil)
        }
        // login multisig
        if let username = credentials.username, !username.isEmpty {
            let backend = gdkNetworkBackend(prominentNetworkId)
            let connParams = createConnectionParams(network: backend.network)
            try await backend.connect(params: connParams)
            loginUserResult = try await backend
                .login(credentials: credentials, device: nil)
        }
        // login boltz
        if let boltzCredentials {
            loginLwkBoltz(
                boltzCredentials: boltzCredentials,
                xpubHashId: parentWalletId!.xpubHashId
            )
        }
        // login lightning
        if let lightningCredentials, let backend = glNetworkBackend() {
            _ = try await loginGl(
                backend: backend,
                credentials: lightningCredentials,
                restore: false,
                parentXpub: parentWalletId!.xpubHashId,
            )
        }
        if loggedInNetworkBackends.isEmpty {
            throw GaError
                .GenericError("id_you_are_not_connected")
        }
        _ = try await updateAccounts()
        isWatchonly = true
        return loginUserResult
    }

    func getWalletIdentifier(credentials: Credentials, networkId: NetworkId) throws -> WalletIdentifier? {
        return try prominentSession
            .getWalletIdentifier(
                netParams: createConnectionParams(
                    network: networkId.gdkNetwork
                ),
                credentials: credentials
            )
    }

    public func loginGdk(
        backend: GdkNetworkBackend,
        credentials: Credentials,
        device: HWDevice?,
        fullRestore: Bool,
        creation: Bool)
    async throws -> LoginUserResult? {
        let network = backend.network
        // Avoid login on multisig by default on new wallet
        if creation && network.multisig {
            return nil
        }
        if network.liquid && device?.supportsLiquid ?? 1 == 0 {
            logger.error("WM login disable liquid if is unsupported on hw")
            return nil
        }
        let walletId = try await getWalletIdentifier(
            network: network,
            credentials: credentials
        )
        guard let walletHashId = walletId?.walletHashId else {
            throw GaError.GenericError("Wallet not found")
        }
        let hasGdkCache = Gdk.shared.hasGdkCache(
            walletHashId: walletHashId
        )
        let res = try await backend.login(credentials: credentials, device: device)
        if network.electrum {
            logger.info("WM \(network.network) BIP44 Discovery")
            let refresh = fullRestore || (!creation && !hasGdkCache)
            let networkAccounts = try await backend.getAccounts(refresh: refresh)
            let walletIsFunded = !networkAccounts.filter {
                $0.bip44Discovered == true
            }.isEmpty
            if walletIsFunded && refresh {
                // Archive no-history default account
                if let firstAccount = networkAccounts.first, firstAccount.pointer == 0 {
                    let hasHistory = await gdkAccountBackend(firstAccount).hasHistory()
                    logger.info("WM \(network.network) Archive no-history default account")
                    if !hasHistory {
                        _ = try await updateAccount(
                            account: firstAccount,
                            isHidden: true,
                            newAccountName: firstAccount.type.title
                        )
                    }
                }
            } else if !hasGdkCache { // Newly discovered Wallet
                // Archive GDK default account
                logger.info("WM \(network.network) Archive GDK default account")
                if let defaultAccount = networkAccounts.first {
                    _ = try await updateAccount(
                        account: defaultAccount,
                        isHidden: true,
                        newAccountName: defaultAccount.type.title
                    )
                }
            }
            // Create GDK bip84Segwit account
            let defaultAccountBip84 = networkAccounts.filter(
                {$0.type == .bip84Segwit
                }).first
            if defaultAccountBip84 == nil {
                logger.info("WM \(network.network) Create GDK bip84Segwit account")
                let accountType = AccountType.bip84Segwit
                _ = try await createAccount(
                    network: network,
                    params: CreateSubaccountParams(
                        name: accountType.description,
                        type: accountType
                    )
                )
            }
        }
        _ = try? await backend.session.loadSettings()
        return res
    }

    public func loginGl(
        backend: GlNetworkBackend,
        credentials: Credentials,
        restore: Bool,
        parentXpub: String
    )
    async throws -> LoginUserResult? {
        try await backend.login(
            credentials: credentials,
            restore: restore,
            parentXpub: parentXpub)
        guard let walletId = try await getWalletIdentifier(
            credentials: credentials
        ) else {
            return nil
        }
        return LoginUserResult(
            xpubHashId: walletId.xpubHashId,
            walletHashId: walletId.walletHashId
        )
    }

    public func loginNetworkBackend(
        backend: NetworkBackend,
        credentials: Credentials,
        lightningCredentials: Credentials?,
        boltzCredentials: Credentials?,
        device: HWDevice?,
        fullRestore: Bool,
        creation: Bool)
    async throws -> LoginUserResult? {
        try await backend
            .connect(params: createConnectionParams(network: backend.network))
        if let backend = backend as? GdkNetworkBackend {
            logger.info("Connecting to gdk backend \(backend.network.network)")
            return try await loginGdk(
                backend: backend,
                credentials: credentials,
                device: device,
                fullRestore: fullRestore,
                creation: creation
            )
        } else if let backend = backend as? GlNetworkBackend, let lightningCredentials {
            logger.info("Connecting to gl backend \(backend.network.network)")
            guard let walletId = try await getWalletIdentifier(credentials: credentials) else {
                throw GaError.GenericError("Invalid credentials")
            }
            return try await loginGl(
                backend: backend,
                credentials: lightningCredentials,
                restore: fullRestore,
                parentXpub: walletId.xpubHashId)
        } else if let backend = backend as? LwkNetworkBackend {
            logger.info("Connecting to lwk backend \(backend.network.network)")
            return try await loginLwk(
                backend: backend,
                credentials: credentials
            )
        }
        return nil
    }

    public func loginLwk(
        backend: LwkNetworkBackend,
        credentials: Credentials)
    async throws -> LoginUserResult? {
        guard let walletId = try await getWalletIdentifier(
            credentials: credentials
        ) else {
            return nil
        }
        try await backend
            .login(
                credentials: credentials
            )
        return LoginUserResult(
            xpubHashId: walletId.xpubHashId,
            walletHashId: walletId.walletHashId
        )
    }

    public func loginLwkBoltz(boltzCredentials: Credentials, xpubHashId: String) {
        deferredLwkLoginTask = Task(priority: .high) {
            _ = try await lwkBoltzBackend?.loginUser(boltzCredentials, xpubHashId: xpubHashId)
        }
    }

    public func login(
        credentials: Credentials,
        lightningCredentials: Credentials?,
        boltzCredentials: Credentials?,
        device: HWDevice?,
        fullRestore: Bool,
        creation: Bool
    ) async throws -> LoginUserResult? {
        //isEphemeral = !(credentials?.bip39Passphrase ?? "").isEmpty
        //isWatchonly = false
        //hwDevice = device
        guard let walletId = try await getWalletIdentifier(credentials: credentials) else {
            throw LoginError.failed()
    }
        await failureSessionsError.reset()
        let loginTask: ((_ backend: NetworkBackend) async -> LoginUserResult?) = { [self] backend in
            do {
                let res = try await loginNetworkBackend(
                    backend: backend,
                    credentials: credentials,
                    lightningCredentials: lightningCredentials,
                    boltzCredentials: boltzCredentials,
                    device: device,
                    fullRestore: fullRestore,
                    creation: creation)
                return res
            } catch {
                await failureSessionsError
                    .add(for: backend.network.networkId, error: error)
                return nil
            }
        }
        //let allSessions = elf.bac
        //let lwkSessions = allSessions.filter { $0.networkType == .lwkMainnet }
        //let mainSessions = allSessions.filter { $0.networkType != .lwkMainnet }
        //logger.info("WM login: \(mainSessions.count) sessions + \(lwkSessions.count) deferred LWK")
        // Only defer LWK if credentials exist; HW wallets provide them later via BIP85 export
        if let boltzCredentials {
            loginLwkBoltz(boltzCredentials: boltzCredentials, xpubHashId: walletId.xpubHashId)
        }
        let loginUserDatas = await withTaskGroup(
            of: (NetworkId, LoginUserResult?).self
        ) { group in
            for backend in networkBackends {
                group.addTask(priority: .high) {
                    return (backend.key, await loginTask(backend.value))
                }
            }
            return await group.reduce(into: [:]) { acc, item in acc[item.0] = item.1 }
        }
        let loggedBackends = networkBackends.filter { $0.value.isLoggedIn }
        logger.info("WM sessions: \(loggedBackends.count)")
        if loggedBackends.count == 0 {
            throw LoginError.failed()
        }
        let accounts = try await updateAccounts()
        logger.info("WM subaccounts: \(accounts.count)")
        //try? await self.syncSettings(restore: fullRestore)
        return loginUserDatas.first { $0.key == prominentNetworkId }?.value
    }

    public func removeDatadir(_ dir: String) throws {
        try FileManager.default.removeItem(atPath: dir)
    }
}

// Assets functions

extension WalletManager {
    public func getAsset(_ assetId: String?) -> AssetInfo {
        let info = registry.info(for: assetId ?? "", provider: self)
        return AssetInfo(
            assetId: info.assetId,
            name: info.name,
            precision: info.precision ?? 8,
            ticker: info.ticker
        )
    }
    public func hasAssetIcon(_ assetId: String?) -> Bool {
        registry.hasImage(for: assetId ?? "", provider: self)
    }
    public func info(for key: String?) -> AssetInfo {
        registry.info(for: key ?? "", provider: self)
    }

    public func image(for key: String?) -> UIImage {
        registry.image(for: key ?? "", provider: self)
    }

    public func hasImage(for key: String?) -> Bool {
        registry.hasImage(for: key ?? "", provider: self)
    }

    public func refreshRegistryIfNeeded() async throws {
        let interval = CFAbsoluteTimeGetCurrent() - (updatedRegistryAt ?? .zero)
        if updatedRegistryAt == nil || interval > 120 {
            registry.refresh(provider: self)
            updatedRegistryAt = CFAbsoluteTimeGetCurrent()
            newNotificationDelegate?
                .didReceive(event: .refreshAssets, networkId: .electrumLiquid)
        }
    }
}
extension WalletManager: AssetsProvider {
    public func getAssets(params: GetAssetsParams) -> GetAssetsResult? {
        let networkId = activeLiquidNetworkIds.first ?? .electrumLiquid
        let gdkNetworkBackend = gdkNetworkBackend(networkId)
        return gdkNetworkBackend.session.getAssets(params: params)
    }

    public func refreshAssets(icons: Bool, assets: Bool) async throws {
        let networkId = activeLiquidNetworkIds.first ?? .electrumLiquid
        let gdkNetworkBackend = gdkNetworkBackend(networkId)
        try await gdkNetworkBackend.session.refreshAssets(icons: icons, assets: assets)
    }
}
extension WalletManager: ConverterProvider {
    public func convertBitcoinAmount(params: Balance) throws -> Balance? {
        let networkId = activeBitcoinNetworkIds.first ?? prominentNetworkId
        let gdkNetworkBackend = gdkNetworkBackend(networkId)
        return try gdkNetworkBackend.convert(params: params)
    }

    public func convertLiquidAmount(params: Balance) throws -> Balance? {
        guard let networkId = activeLiquidNetworkIds.first else {
            throw GaError.GenericError("No liquid network")
        }
        let gdkNetworkBackend = gdkNetworkBackend(networkId)
        return try gdkNetworkBackend.convert(params: params)
    }
}

extension WalletManager: NewNotificationDelegate {
    public func didReceive(
        event: EventNotificationTypes,
        networkId: NetworkId
    ) {
        logger.info("WalletManager didReceive on \(networkId.rawValue)")
        newNotificationDelegate?.didReceive(event: event, networkId: networkId)
    }
}
