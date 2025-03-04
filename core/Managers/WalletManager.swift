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

    public var popupResolver: PopupResolverDelegate? = nil {
        didSet {
            sessions.forEach { $0.value.popupResolver = popupResolver }
        }
    }
    public var hwProtocol: HWProtocol? = nil {
        didSet {
            sessions.forEach { $0.value.hwProtocol = hwProtocol }
        }
    }
    
    public var hwInterfaceResolver: HwInterfaceResolver? = nil {
        didSet {
            sessions.forEach { $0.value.hwInterfaceResolver = hwInterfaceResolver }
        }
    }

    // Store active subaccount
    private var activeWalletHash: Int?
    public var currentSubaccount: WalletItem? {
        get {
            if activeWalletHash == nil {
                return subaccounts.first { $0.hidden == false }
            }
            return subaccounts.first { $0.hashValue == activeWalletHash}
        }
        set {
            if let newValue = newValue {
                activeWalletHash = newValue.hashValue
                if let index = subaccounts.firstIndex(where: { $0.pointer == newValue.pointer && $0.network == newValue.network}) {
                    subaccounts[index] = newValue
                }
            }
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
        self.registry = AssetsManager(testnet: !mainnet)
        self.account = account
        if account.isDerivedLightning {
            addSession(for: prominentNetwork ?? .bitcoinSS)
            addLightningSession(for: .lightning)
        } else if mainnet {
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

    public func loginWithPin(
        pin: String,
        pinData: PinData,
        bip39passphrase: String?)
    async throws {
        guard let mainSession = prominentSession else {
            fatalError()
        }
        try await mainSession.connect()
        let decryptData = DecryptWithPinParams(pin: pin, pinData: pinData)
        var credentials = try await mainSession.decryptWithPin(decryptData)
        // for bip39passphrase login, singlesig is the prominent network
        if !bip39passphrase.isNilOrEmpty {
            credentials = Credentials(mnemonic: credentials.mnemonic, bip39Passphrase: bip39passphrase)
        }
        let lightningCredentials = Credentials(mnemonic: try getLightningMnemonic(credentials: credentials), bip39Passphrase: bip39passphrase)
        let walletIdentifier = try mainSession.walletIdentifier(credentials: credentials)
        try await self.login(credentials: credentials, lightningCredentials: lightningCredentials, parentWalletId: walletIdentifier)
        AccountsRepository.shared.current = self.account
    }

    public func create(_ credentials: Credentials) async throws {
        let btcNetwork: NetworkSecurityCase = testnet ? .testnetSS : .bitcoinSS
        let btcSession = self.sessions[btcNetwork.rawValue]!
        try await btcSession.connect()
        try await btcSession.register(credentials: credentials)
        let loginData = try await btcSession.loginUser(credentials, restore: false)
        account.xpubHashId = loginData.xpubHashId
        AccountsRepository.shared.current = self.account
        try await btcSession.updateSubaccount(UpdateSubaccountParams(subaccount: 0,  hidden: true))
        _ = try await self.subaccounts()
        try? await self.loadRegistry()
    }

    public func loginWatchonly(credentials: Credentials) async throws {
        guard let session = prominentSession else { fatalError() }
        let loginData = try await session.loginUser(credentials: credentials, restore: false)
        self.account.xpubHashId = loginData.xpubHashId
        AccountsRepository.shared.current = self.account
        _ = try await self.subaccounts()
        try? await self.loadRegistry()
    }

    public func loginSessionLightning(
        session: LightningSessionManager,
        credentials: Credentials,
        fullRestore: Bool = false,
        parentWalletId: WalletIdentifier?)
    async throws {
        if !AppSettings.shared.experimental {
            return
        }
        let walletId = try session.walletIdentifier(credentials: credentials)
        var existDatadir = session.existDatadir(walletHashId: walletId?.walletHashId ?? "")
        if session.networkType.lightning && !existDatadir {
            // Check legacy lightning dir using main credentials
            existDatadir = session.existDatadir(walletHashId: parentWalletId?.walletHashId ?? "")
        }
        if !fullRestore && !existDatadir {
            return
        }
        let removeDatadir = !existDatadir
        let res = try await session.loginUser(credentials: credentials, hw: nil, restore: fullRestore)
        self.account.lightningWalletHashId = res.walletHashId
        if session.logged && (fullRestore || !existDatadir) {
            let isFunded = try? await session.discovery()
            if !(isFunded ?? false) && removeDatadir {
                if session.isRestoredNode ?? false {
                    return
                }
                try? await session.disconnect()
                if let walletHashId = walletId?.walletHashId {
                    await session.removeDatadir(walletHashId: walletHashId)
                }
            }
        }
        if fullRestore && session.logged {
            try await addLightningShortcut(credentials: credentials)
        }
    }

    public func loginSession(
        session: SessionManager,
        credentials: Credentials?,
        device: HWDevice? = nil,
        masterXpub: String? = nil,
        fullRestore: Bool = false)
     async throws {
        if session.gdkNetwork.liquid && device?.supportsLiquid ?? 1 == 0 {
            // disable liquid if is unsupported on hw
            return
        }
        let walletId = {
            if let credentials = credentials {
                return try session.walletIdentifier(credentials: credentials)
            } else if device != nil, let masterXpub = masterXpub {
                return try session.walletIdentifier(masterXpub: masterXpub)
            }
            return nil
        }
        let walletHashId = try walletId()!.walletHashId
        var existDatadir = session.existDatadir(walletHashId: walletHashId)
        if !fullRestore && !existDatadir && session.gdkNetwork.network != prominentSession?.gdkNetwork.network {
            return
        }
        let removeDatadir = !existDatadir && session.gdkNetwork.network != self.prominentNetwork.network
        let res = try await session.loginUser(credentials: credentials, hw: device, restore: fullRestore)
        if session.gdkNetwork.network == self.prominentNetwork.network {
            self.account.xpubHashId = res.xpubHashId
            self.account.walletHashId = res.walletHashId
        }
        if session.logged && (fullRestore || !existDatadir) {
            let isFunded = try? await session.discovery()
            if !(isFunded ?? false) && removeDatadir {
                try? await session.disconnect()
                await session.removeDatadir(walletHashId: walletHashId)
            }
        }
    }

    public func loginHW(
        lightningCredentials: Credentials?,
        device: HWDevice?,
        masterXpub: String,
        fullRestore: Bool)
    async throws {
        guard let session = sessions[prominentNetwork.rawValue] else { fatalError() }
        let walletId = try session.walletIdentifier(masterXpub: masterXpub)
        try await login(
           credentials: nil,
           lightningCredentials: lightningCredentials,
           device: device,
           masterXpub: masterXpub,
           fullRestore: fullRestore,
           parentWalletId: walletId
        )
    }

    public func loginSW(
        credentials: Credentials?,
        lightningCredentials: Credentials?,
        fullRestore: Bool,
        parentWalletId: WalletIdentifier?)
    async throws {
        try await login(
           credentials: nil,
           lightningCredentials: lightningCredentials,
           fullRestore: fullRestore,
           parentWalletId: parentWalletId)
    }

    public func login(
        credentials: Credentials? = nil,
        lightningCredentials: Credentials? = nil,
        device: HWDevice? = nil,
        masterXpub: String? = nil,
        fullRestore: Bool = false,
        parentWalletId: WalletIdentifier?
    )
    async throws {
        let walletId: ((_ session: SessionManager) throws -> WalletIdentifier?) = { session in
            if let credentials = credentials {
                return try session.walletIdentifier(credentials: credentials)
            } else if device != nil, let masterXpub = masterXpub {
                return try session.walletIdentifier(masterXpub: masterXpub)
            }
            return nil
        }
        guard let prominentSession = sessions[prominentNetwork.rawValue] else { fatalError() }
        let existDatadir = try prominentSession.existDatadir(walletHashId: walletId(prominentSession)!.walletHashId)
        let fullRestore = fullRestore || account.xpubHashId == nil || !existDatadir
        let loginTask: ((_ session: SessionManager) async throws -> ()) = { [self] session in
            do {
                logger.info("WM login \(session.networkType.rawValue, privacy: .public) begin")
                if session.networkType == .lightning {
                    if let session = session as? LightningSessionManager,
                       let credentials = lightningCredentials {
                        try await self.loginSessionLightning(
                            session: session,
                            credentials: credentials,
                            fullRestore: fullRestore,
                            parentWalletId: parentWalletId)
                    }
                } else {
                    try await self.loginSession(
                        session: session,
                        credentials: credentials,
                        device: device,
                        masterXpub: masterXpub,
                        fullRestore: fullRestore)
                }
                logger.info("WM login \(session.networkType.rawValue, privacy: .public) success")
            } catch {
                logger.info("WM login \(session.networkType.rawValue, privacy: .public) failure: \(error, privacy: .public)")
                try? await session.disconnect()
                await failureSessionsError.add(for: session.networkType, error: error)
            }
        }
        await failureSessionsError.reset()
        let sessions = self.sessions.values.filter { !$0.logged }
        logger.info("WM login start: \(sessions.count) sessions")
        await withTaskGroup(of: Void.self) { group in
            for session in sessions {
                group.addTask(priority: .high) { try? await loginTask(session) }
            }
        }
        logger.info("WM login end: \(self.activeSessions.count) sessions")
        if self.activeSessions.count == 0 {
            throw LoginError.failed()
        }
        logger.info("WM subaccounts")
        _ = try await self.subaccounts()
        if fullRestore {
            logger.info("WM syncSettings")
            try? await self.syncSettings()
        }
        logger.info("WM loadRegistry")
        try? await self.loadRegistry()
        logger.info("WM login end")
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
        Task { try await registry.refreshIfNeeded(provider: self) }
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

    public func balances(subaccounts: [WalletItem]) async throws -> [String: Int64] {
        let balances = await withTaskGroup(of: [String: Int64].self, returning: [[String: Int64]].self) { group in
            for account in subaccounts.enumerated() {
                group.addTask {
                    let acc = account.element
                    let satoshi = try? await acc.session?.getBalance(subaccount: acc.pointer, numConfs: 0)
                    if let index = self.subaccounts.firstIndex(where: { $0.hashValue == acc.hashValue }), let satoshi = satoshi {
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

    public func transactions(subaccounts: [WalletItem], first: Int = 0) async throws -> [Transaction] {
        return try await withThrowingTaskGroup(of: [Transaction].self, returning: [Transaction].self) { group in
            for subaccount in subaccounts {
                group.addTask {
                    let txs = try await subaccount.session?.transactions(subaccount: subaccount.pointer, first: UInt32(first))
                    let page = txs?.list.map { Transaction($0.details, subaccount: subaccount.hashValue) }
                    return page ?? []
                }
            }
            return try await group.reduce(into: [Transaction]()) { partial, res in
                partial += res
            }.sorted()
        }
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
        account.getDerivedLightningAccount() != nil
    }

    public func addLightningShortcut(credentials: Credentials) async throws {
        let session = SessionManager(NetworkSecurityCase.bitcoinSS.gdkNetwork)
        try? await session.connect()
        try? await session.register(credentials: credentials)
        _ = try? await session.loginUser(credentials, restore: false)
        if let settings = prominentSession?.settings {
            _ = try? await session.changeSettings(settings: settings)
        }
        let keychain = "\(account.keychain)-lightning-shortcut"
        try AuthenticationTypeHandler.setCredentials(method: .AuthKeyLightning, credentials: credentials, for: keychain)
    }

    public func removeLightningShortcut() async throws {
        let keychain = account.isDerivedLightning ? account.keychain : account.getDerivedLightningAccount()?.keychain ?? ""
        _ = AuthenticationTypeHandler.removeAuth(method: .AuthKeyLightning, for: keychain)

    }

    public func removeLightning() async throws {
        try? await lightningSession?.disconnect()
        if let walletHashId = account.lightningWalletHashId {
            await lightningSession?.removeDatadir(walletHashId: walletHashId)
            LightningRepository.shared.remove(for: walletHashId)
        }
        // reload subaccounts
        if logged {
            _ = try await subaccounts()
        }
    }

    public func unregisterLightning()  async throws {
        // unregister lightning webhook
        let keychain = account.isDerivedLightning ? account.keychain : account.getDerivedLightningAccount()?.keychain ?? ""
        let derivedCredentials = try AuthenticationTypeHandler.getCredentials(method: .AuthKeyLightning, for: keychain)
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
        for subaccount in subaccounts.filter({$0.gdkNetwork.multisig}) {
            if let session = subaccount.session {
                let params = GetUnspentOutputsParams(subaccount: subaccount.pointer, numConfs: 1, addressType: "csv", expiredAt: UInt64(session.blockHeight))
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
