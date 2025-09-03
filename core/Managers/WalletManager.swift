import Foundation
import UIKit
import gdk
import greenaddress
import hw
import lightning

public actor Failures {
    public var errors = [String: Error]()
    func add(for network: NetworkSecurityCase, error: Error) {
        switch error {
        case TwoFactorCallError.failure(let txt):
            if txt.contains("HWW must enable host unblinding for singlesig wallets") {
                errors[network.rawValue] = LoginError.hostUnblindingDisabled(txt)
            } else if txt != "id_login_failed" {
                errors[network.rawValue] = error
            }
        default:
            errors[network.rawValue] = error
        }
    }
    func reset() {
        errors.removeAll()
    }
}

public class WalletManager {

    // Return current WalletManager used for the active user session
    public static var current: WalletManager? {
        let account = AccountsRepository.shared.current
        return WalletsRepository.shared.get(for: account?.id ?? "")
    }

    // Hashmap of available networks with open session
    public var sessions = [String: SessionManager]()

    // Prominent network used for login with stored credentials
    public let prominentNetwork: NetworkSecurityCase

    // Cached subaccounts list
    public var subaccounts = [WalletItem]()

    // Cached subaccounts list
    public var registry: AssetsManager

    // Mainnet / testnet networks
    let mainnet: Bool

    public var isWatchonly: Bool = false

    public var isHW: Bool { account.isHW }

    public var account: Account {
        didSet {
            if AccountsRepository.shared.get(for: account.id) != nil {
                AccountsRepository.shared.upsert(account)
            }
        }
    }

    public var hwDevice: HWDevice? {
        didSet {
            sessions.forEach { $0.value.hw = hwDevice }
        }
    }

    public var popupResolver: PopupResolverDelegate? {
        didSet {
            sessions.forEach { $0.value.popupResolver = popupResolver }
        }
    }
    public var hwProtocol: HWProtocol? {
        didSet {
            sessions.forEach { $0.value.hwProtocol = hwProtocol }
        }
    }
    public var hwInterfaceResolver: HwInterfaceResolver? {
        didSet {
            sessions.forEach { $0.value.hwInterfaceResolver = hwInterfaceResolver }
        }
    }

    // Get active session of the active subaccount
    public var prominentSession: SessionManager? {
        return sessions[prominentNetwork.rawValue]
    }

    // For Countly
    public var activeNetworks: [NetworkSecurityCase] {
        return activeSessions.keys.compactMap { NetworkSecurityCase(rawValue: $0) }
    }

    public init(account: Account, prominentNetwork: NetworkSecurityCase?) {
        self.mainnet = prominentNetwork?.gdkNetwork.mainnet ?? true
        self.prominentNetwork = prominentNetwork ?? .bitcoinSS
        self.registry = AssetsManager(testnet: !mainnet, lightning: AppSettings.shared.experimental)
        self.account = account
        if mainnet {
            addSession(for: .bitcoinSS)
            addSession(for: .liquidSS)
            addSession(for: .bitcoinMS)
            addSession(for: .liquidMS)
            addLightningSession(for: .lightning)
        } else {
            addSession(for: .testnetSS)
            addSession(for: .testnetLiquidSS)
            addSession(for: .testnetMS)
            addSession(for: .testnetLiquidMS)
            // breez not enabled on testnet
        }
    }

    public func disconnect() async {
        try? await lightningSession?.disconnect()
        for session in sessions.values {
            try? await session.disconnect()
        }
    }

    public func addSession(for network: NetworkSecurityCase) {
        let networkName = network.network
        sessions[networkName] = SessionManager(network.gdkNetwork)
    }

    public func getSession(for network: NetworkSecurityCase) -> SessionManager? {
        sessions[network.network]
    }

    public func getSession(for subaccount: WalletItem) -> SessionManager? {
        getSession(for: subaccount.networkType)
    }

    public func addLightningSession(for network: NetworkSecurityCase) {
        let session = LightningSessionManager(network.gdkNetwork)
        session.accountId = account.id
        sessions[network.rawValue] = session
    }

    public var lightningSession: LightningSessionManager? {
        let network: NetworkSecurityCase = testnet ? .testnetLightning : .lightning
        return sessions[network.rawValue] as? LightningSessionManager
    }

    public var lightningSubaccount: WalletItem? {
        return subaccounts.filter {$0.gdkNetwork.lightning }.first
    }

    public var lightningNodeId: String? {
        get {
            return UserDefaults.standard.string(forKey: "\(AppStorageConstants.lightningNodeId.rawValue)_\(account.id)")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "\(AppStorageConstants.lightningNodeId.rawValue)_\(account.id)")
        }
    }

    public var testnet: Bool {
        return !prominentNetwork.gdkNetwork.mainnet
    }

    public var activeSessions: [String: SessionManager] {
        self.sessions.filter { $0.1.logged }
    }

    public var logged: Bool {
        self.activeSessions.count > 0
    }

    public var hasMultisig: Bool {
        let multisigNetworks: [NetworkSecurityCase] =  [.bitcoinMS, .testnetMS, .liquidMS, .testnetLiquidMS]
        return self.activeNetworks.filter { multisigNetworks.contains($0) }.count > 0
    }

    public var failureSessionsError = Failures()

    public func create(_ credentials: Credentials) async throws {
        let networks: [NetworkSecurityCase] = testnet ? [.testnetSS, .testnetLiquidSS] : [.bitcoinSS, .liquidSS]
        for network in networks {
            let session = self.sessions[network.rawValue]!
            try await session.connect()
            try await session.register(credentials: credentials)
        }
        let walletIdentifier = try prominentSession?.walletIdentifier(credentials: credentials)
        try await login(
            credentials: credentials,
            lightningCredentials: nil,
            device: nil,
            masterXpub: nil,
            fullRestore: false,
            parentWalletId: walletIdentifier)
    }

    

    public func loginWatchonly(
        credentials: Credentials,
        lightningCredentials: Credentials? = nil
    ) async throws {
        var loginUserResult: LoginUserResult?
        let allNetworks: [NetworkSecurityCase] = [.bitcoinSS, .liquidSS, .testnetSS, .testnetLiquidSS]
        for network in allNetworks {
            let descriptors = credentials.coreDescriptors?.filter({ Wally.isDescriptor($0, for: network) }) ?? []
            let keys = credentials.slip132ExtendedPubkeys?.filter({ Wally.isPubKey($0, for: network) }) ?? []
            if descriptors.isEmpty && keys.isEmpty {
                continue
            }
            let credentials = Credentials(coreDescriptors: descriptors.isEmpty ? nil : descriptors, slip132ExtendedPubkeys: keys.isEmpty ? nil : keys)
            try? await getSession(for: network)?.connect()
            loginUserResult = try? await getSession(for: network)?.loginUser(credentials)
        }
        if let username = credentials.username, !username.isEmpty {
            let session = account.networkType.liquid ? liquidMultisigSession : bitcoinMultisigSession
            try? await session?.connect()
            loginUserResult = try? await session?.loginUser(credentials)
        }
        if activeSessions.isEmpty {
            throw HWError.Disconnected("id_you_are_not_connected")
        }
        _ = try await subaccounts()
        try? await loadRegistry()
        isWatchonly = true
        account.xpubHashId = loginUserResult?.xpubHashId
    }

    public func loginSession(
        session: SessionManager,
        credentials: Credentials?,
        device: HWDevice?,
        masterXpub: String?,
        fullRestore: Bool
    ) async throws {
        // disable liquid if is unsupported on hw
        if session.gdkNetwork.liquid && device?.supportsLiquid ?? 1 == 0 {
            logger.error("WM login disable liquid if is unsupported on hw")
            return
        }
        // verify session
        if session.networkType == .lightning {
            if !AppSettings.shared.experimental || testnet {
                logger.error("WM login lightning no available")
                return
            } else if credentials == nil {
                logger.error("WM login no credentials found for lightning")
                return
            }
        } else if session.networkType != .lightning && (credentials == nil && device == nil) {
            throw GaError.GenericError("no credentials found for \(session.networkType.rawValue)")
        }
        let session = session.networkType == .lightning ? session as? LightningSessionManager : session
        guard let session = session else {
            logger.error("WM login lightning no available")
            return
        }
        // check existing a previous session
        let existDatadir = {
            if let masterXpub = masterXpub {
                return session.existDatadir(masterXpub: masterXpub)
            } else if let credentials = credentials {
                return session.existDatadir(credentials: credentials)
            }
            return nil
        }() ?? false
        // ignore login on multisig session if not exist a previous session
        if session.gdkNetwork.multisig && !fullRestore && !existDatadir && credentials?.username ?? nil == nil {
            logger.info("WM login no previous active session found for \(session.networkType.rawValue, privacy: .public)")
            return
        }
        // login
        do {
            try await session.connect()
            let res = try await session.loginUser(credentials: credentials, hw: device)
            // update walletHashId and xpubHashId
            if let session = session as? LightningSessionManager, session.gdkNetwork.lightning {
                account.lightningWalletHashId = res.walletHashId
                lightningNodeId = session.lightBridge?.nodeInfo?.id
            } else if session.gdkNetwork.network == prominentNetwork.network {
                account.xpubHashId = res.xpubHashId
                account.walletHashId = res.walletHashId
            }
        } catch {
            // remove multisig session if login is failure
            switch error {
            case TwoFactorCallError.failure(let txt):
                if txt == "id_login_failed" && fullRestore && prominentSession?.networkType != session.networkType {
                    try? await session.disconnect()
                    if let masterXpub = masterXpub {
                        await session.removeDatadir(masterXpub: masterXpub)
                    } else if let credentials = credentials {
                        await session.removeDatadir(credentials: credentials)
                    }
                    return
                }
                throw error
            default:
                throw error
            }
        }
        // discovery and add default subaccounts
        let refresh = fullRestore && session.logged
        try? await session.discovery(refresh: refresh, updateHidden: !existDatadir || fullRestore)
    }

    public func login(
        credentials: Credentials?,
        lightningCredentials: Credentials?,
        device: HWDevice?,
        masterXpub: String?,
        fullRestore: Bool,
        parentWalletId: WalletIdentifier?
    )
    async throws {
        let loginTask: ((_ session: SessionManager) async throws -> ()) = { [self] session in
            do {
                let credentials = session.networkType == .lightning ? lightningCredentials : credentials
                try await loginSession(session: session, credentials: credentials, device: device, masterXpub: masterXpub, fullRestore: fullRestore)
                logger.info("WM \(session.networkType.rawValue, privacy: .public) login")
            } catch {
                logger.info("WM \(session.networkType.rawValue, privacy: .public) failure: \(error, privacy: .public)")
                try? await session.disconnect()
                await failureSessionsError.add(for: session.networkType, error: error)
            }
        }
        await failureSessionsError.reset()
        let sessions = self.sessions.values.filter { !$0.logged }
        logger.info("WM login: \(sessions.count) sessions")
        await withTaskGroup(of: Void.self) { group in
            for session in sessions {
                group.addTask(priority: .high) { try? await loginTask(session) }
            }
        }
        logger.info("WM sessions: \(self.activeSessions.count)")
        if self.activeSessions.count == 0 {
            throw LoginError.failed()
        }
        _ = try await self.subaccounts()
        logger.info("WM subaccounts: \(self.subaccounts.count)")
        if fullRestore {
            logger.info("WM syncSettings")
            try? await self.syncSettings()
        }
        _ = try? await self.prominentSession?.loadSettings()
        logger.info("WM loadRegistry")
        try? await self.loadRegistry()
    }

    public var bitcoinSinglesigNetwork: NetworkSecurityCase { mainnet ? .bitcoinSS : .testnetSS }
    public var liquidSinglesigNetwork: NetworkSecurityCase { mainnet ? .liquidSS : .testnetLiquidSS }
    public var singlesigNetworks: [NetworkSecurityCase] { [bitcoinSinglesigNetwork] + [liquidSinglesigNetwork] }
    public var bitcoinMultisigNetwork: NetworkSecurityCase { mainnet ? .bitcoinMS : .testnetMS }
    public var liquidMultisigNetwork: NetworkSecurityCase { mainnet ? .liquidMS : .testnetLiquidMS }
    public var multisigNetworks: [NetworkSecurityCase] { [bitcoinMultisigNetwork] + [liquidMultisigNetwork] }
    public var bitcoinNetworks: [NetworkSecurityCase] { [bitcoinSinglesigNetwork] + [bitcoinMultisigNetwork] }
    public var liquidNetworks: [NetworkSecurityCase] { [liquidSinglesigNetwork] + [liquidMultisigNetwork] }

    public var liquidSinglesigSession: SessionManager? { sessions[liquidSinglesigNetwork.rawValue] }
    public var bitcoinSinglesigSession: SessionManager? { sessions[bitcoinSinglesigNetwork.rawValue] }
    public var liquidMultisigSession: SessionManager? { sessions[liquidMultisigNetwork.rawValue] }
    public var bitcoinMultisigSession: SessionManager? { sessions[bitcoinMultisigNetwork.rawValue] }

    public var activeBitcoinSessions: [SessionManager] {
        bitcoinNetworks.compactMap { sessions[$0.rawValue] }.filter { $0.logged }
    }
    public var activeLiquidSessions: [SessionManager] {
        liquidNetworks.compactMap { sessions[$0.rawValue] }.filter { $0.logged }
    }
    public var activeSinglesigSessions: [SessionManager] {
        singlesigNetworks.compactMap { sessions[$0.rawValue] }.filter { $0.logged }
    }
    public var activeMultisigSessions: [SessionManager] {
        multisigNetworks.compactMap { sessions[$0.rawValue] }.filter { $0.logged }
    }
    public var activeSinglesigNetworks: [NetworkSecurityCase] {
        activeSinglesigSessions.map { $0.networkType }
    }
    public var activeMultisigNetworks: [NetworkSecurityCase] {
        activeSinglesigSessions.map { $0.networkType }
    }

    public var activeBitcoinMultisig: Bool { sessions[bitcoinMultisigNetwork.rawValue]?.logged ?? false }
    public var activeLiquidMultisig: Bool { sessions[liquidMultisigNetwork.rawValue]?.logged ?? false }

    public var bitcoinSubaccounts: [WalletItem] {
        subaccounts.filter { !$0.hidden }
            .filter { bitcoinNetworks.contains($0.networkType) }
    }
    public var liquidSubaccounts: [WalletItem] {
        subaccounts.filter { !$0.hidden }
            .filter { liquidNetworks.contains($0.networkType) }
    }
    public var liquidAmpSubaccounts: [WalletItem] {
        liquidSubaccounts.filter { $0.type == .amp }
    }
    public var bitcoinSubaccountsWithFunds: [WalletItem] {
        bitcoinSubaccounts.filter { $0.satoshi?.compactMap{ $0.value }.reduce(0, +) ?? 0 > 0 }
    }
    public var liquidSubaccountsWithFunds: [WalletItem] {
        liquidSubaccounts.filter { $0.satoshi?.compactMap{ $0.value }.reduce(0, +) ?? 0 > 0 }
    }
    public func liquidSubaccountsWithAssetIdFunds(assetId: String) -> [WalletItem] {
        liquidSubaccounts.filter { $0.satoshi?.filter{ $0.key == assetId }.compactMap{ $0.value }.reduce(0, +) ?? 0 > 0 }
    }

    func syncSettings() async throws {
        // Prefer Multisig for initial sync as those networks are synced across devices
        // In case of Lightning Shorcut get settings from parent wallet
        let syncNetwork: NetworkSecurityCase? = {
            if activeBitcoinMultisig {
                return bitcoinMultisigNetwork
            } else if activeLiquidMultisig {
                return liquidMultisigNetwork
            } else {
                return prominentSession?.networkType
            }
        }()
        guard let prominentSession = sessions[(syncNetwork ?? .bitcoinSS).rawValue],
              let prominentSettings = try? await prominentSession.loadSettings() else {
            return
        }
        for session in activeSessions {
            _ = try? await session.value.changeSettings(settings: prominentSettings)
            _ = try? await session.value.loadSettings()
        }
    }

    public func loadSystemMessages() async throws -> [SystemMessage] {
        return try await withThrowingTaskGroup(of: SystemMessage.self, returning: [SystemMessage].self) { [weak self] group in
            for session in (self?.activeSessions ?? [String: SessionManager]()).values {
                group.addTask {
                    let text = try? await session.loadSystemMessage()
                    return SystemMessage(text: text ?? "", network: session.gdkNetwork.network)
                }
            }
            return try await group.reduce(into: [SystemMessage]()) { partial, res in
                partial += [res]
            }
        }
    }

    public func loadRegistry() async throws {
        try await registry.cache(provider: self)
        Task.detached { [weak self] in
            if let self = self {
                try await self.registry.refreshIfNeeded(provider: self)
            }
        }
    }

    public func subaccounts(_ refresh: Bool = false) async throws -> [WalletItem] {
        self.subaccounts = try await withThrowingTaskGroup(of: [WalletItem].self, returning: [WalletItem].self) { [weak self] group in
            for session in (self?.activeSessions ?? [String: SessionManager]()).values {
                group.addTask { try await session.subaccounts(refresh) }
            }
            let subaccounts = try await group.reduce(into: [WalletItem]()) { partial, result in
                partial += result
            }.sorted()
            for subaccount in subaccounts {
                let prev = self?.subaccounts.first { $0.network == subaccount.network && $0.pointer == subaccount.pointer }
                subaccount.satoshi = prev?.satoshi
                subaccount.hasTxs = prev?.hasTxs ?? false
            }
            return subaccounts
        }
        return self.subaccounts
    }

    public func subaccount(account: WalletItem) async throws -> WalletItem? {
        let res = try? await account.session?.subaccount(account.pointer)
        if let res = res, let row = self.subaccounts.firstIndex(where: {$0.pointer == account.pointer && $0.gdkNetwork == account.gdkNetwork}) {
            self.subaccounts[row] = res
        }
        return res
    }
    public func subaccountUpdate(account: WalletItem) async throws -> WalletItem? {
        let res = try? await account.session?.subaccount(account.pointer)
        if let res = res, let row = self.subaccounts.firstIndex(where: {$0.pointer == account.pointer && $0.gdkNetwork == account.gdkNetwork}) {
            res.satoshi = account.satoshi
            res.hasTxs = account.hasTxs
            self.subaccounts[row] = res
        }
        return res
    }
    public func balances(subaccounts: [WalletItem]) async throws -> [String: Int64] {
        let balances = await withTaskGroup(of: [String: Int64].self, returning: [[String: Int64]].self) { group in
            for account in subaccounts.enumerated() {
                group.addTask {
                    let acc = account.element
                    let satoshi = try? await acc.session?.getBalance(subaccount: acc.pointer, numConfs: 0)
                    if let index = self.subaccounts.firstIndex(where: { $0.id == acc.id }), let satoshi = satoshi {
                        self.subaccounts[index].satoshi = satoshi
                        self.subaccounts[index].hasTxs = satoshi.count > 1 ? true : account.element.hasTxs
                        self.subaccounts[index].hasTxs = (satoshi.first?.value ?? 0) > 0 ? true : account.element.hasTxs
                    }
                    return satoshi ?? [:]
                }
            }
            return await group.reduce(into: [[String: Int64]]()) { partial, result in
                partial += [result]
            }
        }
        return balances
            .flatMap { $0 }
            .reduce([String: Int64]()) { (dict, tuple) in
                var nextDict = dict
                let prevValue = dict[tuple.key] ?? 0
                nextDict.updateValue(prevValue + tuple.value, forKey: tuple.key)
                return nextDict
            }
    }

    public func transactions(subaccounts: [WalletItem], first: Int = 0, count: Int? = nil) async throws -> [Transaction] {
        return try await withThrowingTaskGroup(of: [Transaction].self, returning: [Transaction].self) { group in
            for subaccount in subaccounts {
                group.addTask {
                    let txs = try await subaccount.session?.transactions(subaccount: subaccount.pointer, first: first)
                    let page = txs?.list.map { Transaction($0.details, subaccountId: subaccount.id) }
                    return page ?? []
                }
            }
            return try await group.reduce(into: [Transaction]()) { partial, res in
                partial += res
            }.sorted()
        }
    }

    public func pagedTransactions(subaccounts: [WalletItem], of page: Int = 0) async throws -> [String: Transactions] {
        return try await withThrowingTaskGroup(of: (String, Transactions).self, returning: [String: Transactions].self) { group in
            for subaccount in subaccounts {
                group.addTask {
                    let txs = try await subaccount.session?.transactions(subaccount: subaccount.pointer, first: page * 30, count: 30)
                    let list = txs?.list.map { Transaction($0.details, subaccountId: subaccount.id) }
                    return (subaccount.id, Transactions(list: list ?? []))
                }
            }
            return try await group.reduce(into: [String: Transactions]()) { partial, res in
                partial[res.0] = res.1
            }
        }
    }
    public func allTransactions(subaccounts: [WalletItem]) async throws -> [Transaction] {
        return try await withThrowingTaskGroup(of: [Transaction].self, returning: [Transaction].self) { group in
            for subaccount in subaccounts {
                group.addTask {
                    let txs = try await self.allBySubaccount(subaccount)
                    return txs
                }
            }
            return try await group.reduce(into: [Transaction]()) { partial, res in
                partial += res
            }.sorted(by: { $0 > $1 })
        }
    }
    func allBySubaccount(_ subaccount: WalletItem) async throws -> [Transaction] {
        let offset = 30
        var page = 0
        var end: Bool = false
        var transactions: [Transaction] = []
        while end == false {
            let txs = try await subaccount.session?.transactions(subaccount: subaccount.pointer, first: page * offset, count: offset)
            let list = txs?.list.map { Transaction($0.details, subaccountId: subaccount.id) } ?? []
            transactions.append(contentsOf: list)
            if list.count < offset {
                end = true
            } else {
                page += 1
            }
        }
        return transactions
    }
    public func bitcoinBlockHeight() -> UInt32? {
        return bitcoinSubaccounts.first?.session?.blockHeight
    }

    public func liquidBlockHeight() -> UInt32? {
        return liquidSubaccounts.first?.session?.blockHeight
    }

    public func pause() async {
        logger.info("WM pause networkDisconnect")
        await withTaskGroup(of: Void.self) { group -> () in
            for session in activeSessions.values {
                if session.connected {
                    group.addTask { await session.networkDisconnect() }
                }
            }
        }
    }

    public func resume() async {
        logger.info("WM resume networkConnect")
        await withTaskGroup(of: Void.self) { group -> () in
            for session in activeSessions.values {
                if session.connected {
                    group.addTask { await session.networkConnect() }
                }
            }
        }
    }

    public func existDerivedLightning() -> Bool {
        AppSettings.shared.experimental && !testnet && AuthenticationTypeHandler.findAuth(method: .AuthKeyLightning, forNetwork: account.keychainLightning)
    }

    public func removeLightning() async {
        try? await lightningSession?.disconnect()
        if let walletHashId = account.lightningWalletHashId {
            await lightningSession?.removeDatadir(walletHashId: walletHashId)
            LightningRepository.shared.remove(for: walletHashId)
        }
        _ = AuthenticationTypeHandler.removeAuth(method: .AuthKeyLightning, for: account.keychainLightning)
        // reload subaccounts
        if logged {
            _ = try? await subaccounts()
        }
    }

    public func unregisterLightning()  async throws {
        // unregister lightning webhook
        let derivedCredentials = try AuthenticationTypeHandler.getCredentials(method: .AuthKeyLightning, for: account.keychainLightning)
        if let session = lightningSession, !session.logged {
            try await session.smartLogin(
                credentials: derivedCredentials,
                listener: session)
        }
        let defaults = UserDefaults(suiteName: Bundle.main.appGroup)
        if let token = defaults?.string(forKey: "token"),
           let xpubHashId = account.xpubHashId {
           lightningSession?.unregisterNotification(token: token, xpubHashId: xpubHashId)
        }
        try? await lightningSession?.disconnect()
    }

    public func getLightningMnemonic(credentials: Credentials) throws -> String? {
        guard let mnemonic = credentials.mnemonic else {
            throw GaError.GenericError("No such mnemonic")
        }
        return Wally.bip85FromMnemonic(mnemonic: mnemonic,
                          passphrase: credentials.bip39Passphrase,
                          isTestnet: false,
                          index: 0)
    }

    public func deriveLightningCredentials(from credentials: Credentials) throws -> Credentials {
        Credentials(
            mnemonic: try getLightningMnemonic(credentials: credentials),
            bip39Passphrase: credentials.bip39Passphrase)
    }

    public func setCloseToAddress() async throws {
        let singlesig = subaccounts.filter { $0.type == .segWit }.first ?? subaccounts.filter { $0.type == .segwitWrapped }.first
        let address = try await singlesig?.session?.getReceiveAddress(subaccount: singlesig?.pointer ?? 0)
        if let address = address?.address {
            try await lightningSession?.lightBridge?.setCloseToAddress(closeToAddress: address)
        }
    }

    public func getExpiredSubaccounts() async throws -> [WalletItem] {
        var expiredSubaccounts = [WalletItem]()
        for subaccount in subaccounts.filter({$0.type == .standard}) {
            if let session = subaccount.session {
                let params = GetUnspentOutputsParams(subaccount: subaccount.pointer, numConfs: 1, expiredAt: UInt64(session.blockHeight))
                let res = try await subaccount.session?.getUnspentOutputs(params)
                for assetUtxos in res ?? [:] {
                    if assetUtxos.value.count > 0 {
                        if !expiredSubaccounts.contains(subaccount) {
                            expiredSubaccounts += [subaccount]
                        }
                    }
                }
            }
        }
        return expiredSubaccounts
    }
}
extension WalletManager {

    public func refreshIfNeeded() async throws {
        try await registry.refreshIfNeeded(provider: self)
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
}
extension WalletManager: AssetsProvider {
    public func getAssets(params: gdk.GetAssetsParams) -> gdk.GetAssetsResult? {
        let session = activeLiquidSessions.first ?? liquidSinglesigSession ?? SessionManager(liquidSinglesigNetwork.gdkNetwork)
        return session.getAssets(params: params)
    }

    public func refreshAssets(icons: Bool, assets: Bool, refresh: Bool) async throws {
        let session = activeLiquidSessions.first ?? liquidSinglesigSession ?? SessionManager(liquidSinglesigNetwork.gdkNetwork)
        if refresh {
            try await session.connect()
        }
        return try await session.refreshAssets(icons: icons, assets: assets, refresh: refresh)
    }
}
