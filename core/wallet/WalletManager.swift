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
        try! gdkNetworkBackend(prominentNetworkId)
    }
    public var prominentSession: SessionManager {
        try! gdkNetworkBackend(prominentNetworkId).session
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
    public var networkErrors = [NetworkId: Error]()
    public var isWatchonly: Bool = false
    public var isEphemeral: Bool = false
    public var isHW: Bool { hwDevice != nil }
    public var isJade: Bool { hwDevice?.isJade ?? false }
    public var isLedger: Bool { hwDevice?.isLedger ?? false }
    public var hwDevice: HWDevice?
    public var updatedRegistryAt: Double?

    // Resolvers
    public var popupResolver: PopupResolverDelegate? {
        didSet {
            for network in networkBackends.keys {
                gdkNetworkBackendOrNil(network)?.session.popupResolver = popupResolver
            }
        }
    }
    public var hwProtocol: HWProtocol? {
        didSet {
            for network in networkBackends.keys {
                gdkNetworkBackendOrNil(network)?.session.hwProtocol = hwProtocol
            }
        }
    }
    public var hwInterfaceResolver: HwInterfaceResolver? {
        didSet {
            for network in networkBackends.keys {
                gdkNetworkBackendOrNil(network)?.session.hwInterfaceResolver = hwInterfaceResolver
            }
        }
    }

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
    public var hasLightning: Bool { glNetworkBackendOrNil()?.isLoggedIn ?? false }
    public var hasLwkAmp: Bool {
        lwkNetworkBackendOrNil(testnet ? .lwkTestnet : .lwkMainnet)?.isLoggedIn ?? false
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
        let backend = try gdkNetworkBackend(network.networkId)
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


    // Get Session Manager

    public func getGdkSession(for network: NetworkId) -> SessionManager? {
        gdkNetworkBackendOrNil(network)?.session
    }
    public func getGdkSession(for account: Account) -> SessionManager? {
        gdkAccountBackendOrNil(account)?.session
    }

    public func getGlSession() -> LightningSessionManager? {
        glNetworkBackendOrNil()?.session
    }

    public var lightningSession: LightningSessionManager? {
        glNetworkBackendOrNil()?.session
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

    public func settings(for network: NetworkId? = nil) -> Settings? {
        let targetNet = network ?? prominentNetworkId
        return gdkNetworkBackendOrNil(targetNet)?.session.settings
    }

    public func twoFactorConfig(for network: NetworkId? = nil) -> TwoFactorConfig? {
        let targetNet = network ?? prominentNetworkId
        return gdkNetworkBackendOrNil(targetNet)?.session.twoFactorConfig
    }

    public func twoFactorReset(for network: NetworkId? = nil) -> TwoFactorReset? {
        let targetNet = network ?? prominentNetworkId
        return gdkNetworkBackendOrNil(targetNet)?.session.twoFactorConfig?.twofactorReset
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

    public func bitcoinBlockHeight() -> UInt32? {
        return activeBitcoinBackends.first?.block?.height
    }

    public func liquidBlockHeight() -> UInt32? {
        return activeLiquidBackends.first?.block?.height
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
    public func networks() -> [NetworkId] {
        if prominentNetwork.mainnet {
            return [
                .electrumMainnet,
                .greenMainnet,
                .electrumLiquid,
                .greenLiquid,
                // AMP2 mainnet server config is not available yet; keep LWK testnet-only.
                .lightningMainnet
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

    public func getExpiredSubaccounts() async throws -> [Account] {
        var expiredSubaccounts = [Account]()
        for subaccount in accounts.filter({$0.type == .standard}) {
            let networkBackend = try gdkNetworkBackend(subaccount.networkId)
            let accountBackend = try gdkAccountBackend(subaccount)
            let res = try await accountBackend.getUnspentOutputs(
                isBump: false,
                isExpired: true,
                expiredAt: UInt64(networkBackend.block?.height ?? 0)
            )
            for assetUtxos in res where assetUtxos.value.count > 0 {
                if !expiredSubaccounts.contains(subaccount) {
                    expiredSubaccounts += [subaccount]
                }
            }
        }
        return expiredSubaccounts
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
