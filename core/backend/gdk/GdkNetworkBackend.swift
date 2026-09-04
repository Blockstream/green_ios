import Foundation
import greenaddress
import Combine
import hw

public final class GdkNetworkBackend: NetworkBackend {

    public let network: GdkNetwork
    public var accounts: [Account]
    public var block: Block?
    public private(set) var session: SessionManager

    public var isConnected = false
    public var isLoggedIn = false
    public var isWatchOnly = false
    public var authenticationRequired = false
    public var logged: Bool { isLoggedIn }
    public var gdkNetwork: GdkNetwork { network }
    public var networkId: NetworkId { network.networkId }
    public var networkType: NetworkId { network.networkId }
    private var accountBackends = [String: AccountBackend]()
    public weak var newNotificationDelegate: NewNotificationDelegate?
    public weak var popupResolver: PopupResolverDelegate?
    public var hwResolver: HwResolverDelegate?
    public weak var hwInterfaceResolver: HwInterfaceResolver?
    public var hwProtocol: HWProtocol? {
        didSet {
            session.hwProtocol = hwProtocol
        }
    }
    //  Disable notification handling until all networks are initialized
    var disableNotificationHandling = false

    private let blockDebouncer = NotificationDebouncer(interval: .milliseconds(300))
    private let transactionDebouncer = NotificationDebouncer(interval: .milliseconds(300))

    public var twoFactorConfig: TwoFactorConfig?
    public var settings: Settings?


    public init(
        network: GdkNetwork,
        popupResolver: PopupResolverDelegate? = nil,
        hwResolver: HwResolverDelegate? = nil,
        hwProtocol: HWProtocol? = nil,
        hwInterfaceResolver: HwInterfaceResolver? = nil,
        newNotificationDelegate: NewNotificationDelegate?
    ) {
        self.network = network
        self.accounts = []
        self.popupResolver = popupResolver
        self.hwResolver = hwResolver
        self.hwProtocol = hwProtocol
        self.hwInterfaceResolver = hwInterfaceResolver
        self.newNotificationDelegate = newNotificationDelegate
        self.disableNotificationHandling = true
        self.session = SessionManager(network.networkId)
        self.session.newNotificationDelegate = self
        self.setupSession()
    }

    private func setupSession() {
        session.hwProtocol = self.hwProtocol
        session.hwResolver = self.hwResolver
        session.newNotificationDelegate = self
        session.popupResolver = self
        session.hwInterfaceResolver = self
    }

    deinit {
        blockDebouncer.cancel()
        transactionDebouncer.cancel()
        newNotificationDelegate = nil
    }

    private func debounce(event: EventNotificationTypes) {
        switch event {
        case .newBlock(let block):
            if block.height > 0 {
                self.block = block
            }
            guard block.height > 0 && !disableNotificationHandling else {
                return
            }
            blockDebouncer.schedule(event) { [weak self] events in
                self?.handleBlockEvents(events)
            }
        case .newTransaction:
            // Avoid handle newTransaction during wallet restoring
            guard block?.height ?? 0 > 0 && !disableNotificationHandling else {
                return
            }
            transactionDebouncer.schedule(event) { [weak self] events in
                self?.handleTransactionEvents(events)
            }
        default:
            break
        }
    }

    private func syncTransactions(
        for accountBackend: AccountBackend
    ) async throws {
        let mempoolCount = (accountBackend as? GdkAccountBackend)?
            .txs.values.filter { $0.blockHeight == 0 }.count ?? 0
        let count = max(30, mempoolCount)
        _ = try await accountBackend.getBalance(confirmations: 0)
        _ = try await accountBackend.getTransactions(
            params: GetTransactionsParams(
                subaccount: accountBackend.account.pointer,
                first: 0,
                count: count
            )
        )
    }

    private func handleBlockEvents(_ events: [EventNotificationTypes]) {
        guard case .newBlock(let block) = events.last, block.height > 0 else { return }

        Task { [weak self] in
            guard let self else { return }
            self.block = block
            for accountBackend in self.accountBackends.values {
                let pendingTxs = self.pendingTransactions(block: block, accountBackend: accountBackend)
                if !pendingTxs.isEmpty {
                    try? await self.syncTransactions(
                        for: accountBackend
                    )
                }
            }
            self.newNotificationDelegate?
                .didReceive(event: .newBlock(block: block), networkId: networkId)
        }
    }

    private func handleTransactionEvents(_ events: [EventNotificationTypes]) {
        var subaccounts = Set<UInt32>()
        for event in events {
            guard case .newTransaction(let tx) = event, let pointers = tx.subAccounts else { continue }
            for pointer in pointers {
                subaccounts.insert(pointer)
            }
        }

        Task { [weak self] in
            guard let self else { return }
            if !subaccounts.isEmpty {
                for accountBackend in self.accountBackends.values {
                    let pointer = accountBackend.account.pointer
                    guard subaccounts.contains(pointer) else { continue }
                    try? await self.syncTransactions(
                        for: accountBackend
                    )
                }
            }
            if case .newTransaction(let tx) = events.last {
                self.newNotificationDelegate?
                    .didReceive(event: .newTransaction(transaction: tx), networkId: networkId)
            }
        }
    }

    private func pendingTransactions(block: Block, accountBackend: AccountBackend) -> [Transaction] {
        let minConfirmations = networkId.liquid ? 2 : 6
        let pendingTxs = accountBackend.txs.values.filter {
            $0.confirmations(block: block.height) <= minConfirmations
        }
        return pendingTxs
    }

    public func accountBackend(_ account: Account) -> AccountBackend {
        if let accountBackend = accountBackends[account.id] {
            return accountBackend
        } else {
            let accountBackend = createAccountBackend(account: account)
            accountBackends[account.id] = accountBackend
            return accountBackend
        }
    }

    public func createAccountBackend(account: Account) -> AccountBackend {
        return GdkAccountBackend(
            networkBackend: self,
            account: account,
            session: session
        )
    }

    private func loginUser(
        credentials: Credentials?,
        device: HWDevice?
    ) async throws -> LoginUserResult {
        if let device {
            let res = try await session.loginUser(device)
            isLoggedIn = true
            return res
        } else if let credentials {
            let res = try await session.loginUser(credentials)
            isLoggedIn = true
            return res
        } else {
            throw GaError.GenericError("Credentials or Device is required")
        }
    }

    public func isPolicyAsset(assetId: String?) -> Bool {
        if network.liquid {
            return network.policyAsset == assetId
        } else {
            return assetId == nil || assetId == AssetInfo.btcId
        }
    }

    public func connect(params: ConnectionParams) async throws {
        guard !isConnected else { return }
        try await session.connect(network: self.gdkNetwork.network)
        isConnected = true
        AnalyticsManager.shared.setupSession(session: session.session)
    }

    public func isAddressValid(address: String) async throws -> Bool {
        let params = ValidateAddresseesParams(
            addressees: [Addressee.from(address: address, satoshi: nil, assetId: nil)],
            network: network.network
        )
        let res: ValidateAddresseesResult = try await session.wrapper(
            fun: self.session.session?.validate,
            params: params
        ) as ValidateAddresseesResult
        return res.isValid
    }

    public func getAccounts(refresh: Bool) async throws -> [Account] {
        let res = try await session.subaccounts(refresh)
        accounts = res
        return res

    }

    public func getAccount(account: Account) async throws -> Account {
        let res = try await session.subaccount(account.pointer)
        if let index = accounts.firstIndex(where: { $0.id == res.id }) {
            accounts[index] = res
        } else {
            accounts += [res]
        }
        return res
    }

    public func disconnect() async throws {
        try await session.disconnect()
        isLoggedIn = false
        isConnected = false
        hwResolver = nil
    }

    public func createAccount(params: CreateSubaccountParams) async throws -> Account {
        try await session.createSubaccount(params)
    }

    public func broadcastTransaction(broadcastTransaction: BroadcastTransactionParams) async throws -> SendTransactionSuccess {
        try await session.broadcastTransaction(broadcastTransaction)
    }

    public func sendTransaction(params: Transaction) async throws -> SendTransactionSuccess {
        try await session.sendTransaction(tx: params)
    }

    func convert(params: Balance) throws -> Balance? {
        guard var input = params.toDict() else {
            throw GaError.GenericError("Conversion error")
        }
        // normalize for asset info
        if let assetId = params.assetId {
            if AssetInfo.baseIds.contains(assetId) {
                input["asset_id"] = nil
                input["asset_info"] = nil
            } else if let assetValue = params.assetValue {
                input[assetId] = assetValue
            }
        }
        // call convert amount
        let res = try session.convertAmount(input: input)
        guard var balance = Balance.from(res) as? Balance else {
            throw GaError.GenericError("Conversion error")
        }
        // normalize result for assets
        if let assetId = params.assetId {
            balance.assetId = assetId
            if let assetValue = res[assetId] as? String {
                balance.assetValue = assetValue
            }
            if let assetInfo = params.assetInfo {
                balance.assetInfo = assetInfo
            }
        }
        return balance
    }

    public func blindTransaction(tx: Transaction) async throws -> Transaction {
        try await session.blindTransaction(tx: tx)
    }

    public func getPsbt(tx: Transaction) async throws -> String? {
        try await session.getPsbt(tx: tx)
    }

    public func psbtGetDetails(params: PsbtGetDetailParams) async throws -> Transaction {
        return try await session.psbtGetDetails(params: params)
    }

    public func createRedepositTransaction(params: CreateRedepositTransactionParams) async throws -> Transaction {
        try await session.createRedepositTransaction(params: params)
    }

    public func login(
        credentials: Credentials,
        device: HWDevice?,
        fullRestore: Bool,
        creation: Bool,
        prominentNetworkId: NetworkId
    )
    async throws -> LoginUserResult? {
        disableNotificationHandling = true
        // Disable gdk login on multisig on new wallet
        // Disable gdl liquid login, if hw doesn't support it
        if network.liquid && device?.supportsLiquid ?? 1 == 0 {
            logger.error("WM login disable liquid if is unsupported on hw")
            return nil
        }
        // Access by multisig watchonly credentials
        if credentials.isMultisigWatchonly {
            if network.multisig && networkId == prominentNetworkId {
                if !credentials.username.isNilOrEmpty {
                    let credentials = Credentials(
                        username: credentials.username,
                        password: credentials.password
                    )
                    return try await loginUser(credentials: credentials, device: nil)
                }
            }
            return nil
        }
        // Access by singlesig watchonly credentials
        if credentials.isSinglesigWatchonly {
            if network.singlesig {
                let descriptors = credentials.coreDescriptors?.filter(
                    { Wally.isDescriptor($0, for: network.networkId)
                    })
                let slip132Keys = credentials.slip132ExtendedPubkeys?.filter({ Wally.isPubKey($0, for: network.networkId) })
                if !descriptors.isNilOrEmpty || !slip132Keys.isNilOrEmpty {
                    let credentials = Credentials(
                        coreDescriptors: descriptors,
                        slip132ExtendedPubkeys: slip132Keys
                    )
                    return try await loginUser(credentials: credentials, device: nil)
                }
            }
            return nil
        }
        // Read previous wallet cache
        guard let walletIdentifier = try session.getWalletIdentifier(gdkNetwork: network.network, credentials: credentials) else {
            throw GaError.GenericError("Wallet not found")
        }
        let hasGdkCache = Gdk.shared.hasGdkCache(
            walletHashId: walletIdentifier.walletHashId
        )
        // Access by software/hardware credentials
        do {
            let res = try await loginUser(credentials: credentials, device: device)
            let refresh = fullRestore || (!creation && !hasGdkCache)
            try? await discoveryAndSetupDefaultsAccounts(
                walletHashId: walletIdentifier.walletHashId,
                discovery: refresh,
                setDefaultAccounts: (!hasGdkCache && !network.multisig) || creation || fullRestore
            )
            try? await loadSettings()
            // Allow initialization calls to have priority over notifications initiated updates
            disableNotificationHandling = false
            return res
        } catch TwoFactorCallError.failure(let txt) {
            if txt.contains("HWW must enable host unblinding for singlesig wallets") {
                throw LoginError.hostUnblindingDisabled(txt)
            } else if txt == "id_login_failed" && network.electrum {
                throw LoginError.failed(txt)
            }
            return nil
        } catch {
            throw error
        }
    }

    func discoveryAndSetupDefaultsAccounts(
        walletHashId: String,
        discovery: Bool,
        setDefaultAccounts: Bool) async throws {
        let networkAccounts = try await getAccounts(refresh: discovery)
        let walletIsFunded = !networkAccounts.filter {
            $0.bip44Discovered == true
        }.isEmpty
        if walletIsFunded && discovery {
            // Archive no-history default account
            if let firstAccount = networkAccounts.first, firstAccount.pointer == 0 {
                let accountBackend = accountBackend(
                    firstAccount
                ) as? GdkAccountBackend
                let hasHistory = await accountBackend?.hasHistory() ?? false
                logger.info("WM \(self.network.network) Archive no-history default account")
                if !hasHistory {
                    _ = try await updateAccount(
                        account: firstAccount,
                        name: firstAccount.type.title,
                        hidden: true
                    )
                }
            }
        } else if setDefaultAccounts { // Newly discovered Wallet
            // Archive GDK default account only when it has no history
            logger.info("WM \(self.network.network) Archive GDK default account")
            if let defaultAccount = networkAccounts.first {
                let accountBackend = accountBackend(
                    defaultAccount
                ) as? GdkAccountBackend
                let hasHistory = await accountBackend?.hasHistory() ?? false
                if !hasHistory {
                    _ = try await updateAccount(
                        account: defaultAccount,
                        name: defaultAccount.type.title,
                        hidden: true
                    )
                }
            }
        }
        // Create GDK bip84Segwit account
        let defaultAccountBip84 = networkAccounts.filter(
            {$0.type == .bip84Segwit
            }).first
        if network.singlesig && defaultAccountBip84 == nil {
            logger.info("WM \(self.network.network) Create GDK bip84Segwit account")
            let accountType = AccountType.bip84Segwit
            _ = try await createAccount(
                params: CreateSubaccountParams(
                    name: accountType.description,
                    type: accountType
                )
            )
        }
    }
    public func updateAccount(account: Account, name: String? = nil, hidden: Bool? = nil) async throws {
        let accountBackend = accountBackend(
            account
        ) as? GdkAccountBackend
        try await accountBackend?.updateAccount(
            name: name ?? account.name,
            hidden: hidden ?? account.hidden
        )
    }

    public func loadSettings() async throws {
        self.settings = try await self.session.getSettings()
        if networkId.multisig {
            self.twoFactorConfig = try await session.getTwoFactorConfig()
        }
    }
    public func setCsvTimeLock(csv: CsvTime) async throws {
        guard let values = csv.value(for: gdkNetwork) else {
            throw GaError.GenericError("Invalid csv")
        }
        try await session.setCSVTime(value: values)
        try await loadSettings()
    }
    public func resetTwoFactor(email: String, isDispute: Bool) async throws {
        try await session.resetTwoFactor(email: email, isDispute: isDispute)
        try await loadSettings()
    }
    public func cancelTwoFactorReset() async throws {
        try await session.cancelTwoFactorReset()
        try await loadSettings()
    }
    public func undoTwoFactorReset(email: String) async throws {
        try await session.undoTwoFactorReset(email: email)
        try await loadSettings()
    }
    public func changeSettings(_ param: Settings) async throws {
        try await session.changeSettings(param)
        try await loadSettings()
    }
    public func changeSettingsTwoFactor(_ param: ChangeSettingsTwoFactorParams) async throws {
        try await session.changeSettingsTwoFactor(param)
        try await loadSettings()
    }
    public func setTwoFactorLimit(_ param: TwoFactorConfigLimits) async throws {
        try await session.setTwoFactorLimit(param)
        try await loadSettings()
    }
    public func sendNlocktimes() async throws {
        try await session.session?.sendNlocktimes()
        try await loadSettings()
    }

}

extension GdkNetworkBackend: NewNotificationDelegate {
    public func didReceive(
        event: EventNotificationTypes,
        networkId: NetworkId
    ) {
        switch event {
        case .newBlock(let block):
            logger
                .info(
                    "GdkNetworkBackend didReceive newBlock(\(block.height)) on \(networkId.network)"
                )
            debounce(event: event)
        case .newTransaction(let tx):
            logger
                .info(
                    "GdkNetworkBackend didReceive newTransaction(\(tx.txHash ?? "", privacy: .public)) on \(networkId.network, privacy: .public)"
                )
            debounce(event: event)
        case .twoFactorReset:
            logger
                .info(
                    "GdkNetworkBackend didReceive twoFactorReset on \(networkId.network)"
                )
            guard !disableNotificationHandling else {
                return
            }
            Task { [weak self, weak newNotificationDelegate] in
                try await self?.loadSettings()
                newNotificationDelegate?
                    .didReceive(event: event, networkId: networkId)
            }
        case .updateSettings:
            logger
                .info(
                    "GdkNetworkBackend didReceive updateSettings on \(networkId.network)"
                )
            guard !disableNotificationHandling else {
                return
            }
            Task { [weak self, weak newNotificationDelegate] in
                try await self?.loadSettings()
                newNotificationDelegate?
                    .didReceive(event: event, networkId: networkId)
            }
        case .disconnected:
            logger
                .info(
                    "GdkNetworkBackend didReceive disconnect on \(networkId.network)"
                )
            newNotificationDelegate?
                .didReceive(event: event, networkId: networkId)
        case .reconnected:
            logger
                .info(
                    "GdkNetworkBackend didReceive reconnected on \(networkId.network)"
                )
            newNotificationDelegate?
                .didReceive(event: event, networkId: networkId)
        case .tor:
            newNotificationDelegate?
                .didReceive(event: event, networkId: networkId)
        case .newSubaccount(let subaccount):
            logger
                .info(
                    "GdkNetworkBackend didReceive newSubaccount on \(networkId.network)"
                )
            guard !disableNotificationHandling else {
                return
            }
            newNotificationDelegate?
                .didReceive(event: event, networkId: networkId)
        default:
            break
        }
    }
}

private final class NotificationDebouncer {
    private let interval: DispatchTimeInterval
    private var buffer: [EventNotificationTypes] = []
    private var workItem: DispatchWorkItem?

    init(interval: DispatchTimeInterval) {
        self.interval = interval
    }

    func schedule(_ event: EventNotificationTypes, handler: @escaping ([EventNotificationTypes]) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.buffer.append(event)
            self.workItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                let events = self.buffer
                self.buffer.removeAll()
                self.workItem = nil
                handler(events)
            }
            self.workItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + self.interval, execute: work)
        }
    }

    func cancel() {
        if Thread.isMainThread {
            workItem?.cancel()
            workItem = nil
            buffer.removeAll()
        } else {
            DispatchQueue.main.sync {
                workItem?.cancel()
                workItem = nil
                buffer.removeAll()
            }
        }
    }
}

extension GdkNetworkBackend: PopupResolverDelegate {
    public func code(_ method: String, attemptsRemaining: Int?, enable2faCallMethod: Bool, network: NetworkId, failure: Bool) async throws -> String {
        guard let popupResolver else {
            throw GaError.GenericError("2FA resolver failed")
        }
        return try await popupResolver.code(
            method,
            attemptsRemaining: attemptsRemaining,
            enable2faCallMethod: enable2faCallMethod,
            network: network,
            failure: failure
        )
    }

    public func method(_ methods: [String]) async throws -> String {
        guard let popupResolver else {
            throw GaError.GenericError("2FA resolver failed")
        }
        return try await popupResolver.method(methods)
    }

}

extension GdkNetworkBackend: HwResolverDelegate {
    public func resolveCode(action: String, device: hw.HWDevice, requiredData: [String : Any], chain: String?, hwDevice: (any hw.HWProtocol)?, interfaceDelegate: HwInterfaceResolver?) async throws -> hw.HWResolverResult {
        guard let hwResolver else {
            throw GaError.GenericError("2FA resolver failed")
        }
        return try await hwResolver
            .resolveCode(
                action: action,
                device: device,
                requiredData: requiredData,
                chain: chain,
                hwDevice: hwDevice,
                interfaceDelegate: self
            )
    }
}

extension GdkNetworkBackend: HwInterfaceResolver {
    public func showMasterBlindingKeyRequest() async {
        await hwInterfaceResolver?.showMasterBlindingKeyRequest()
    }

    public func dismiss() async {
        await hwInterfaceResolver?.dismiss()
    }
}
