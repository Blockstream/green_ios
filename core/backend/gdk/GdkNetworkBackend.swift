import Foundation
import Combine
import greenaddress
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

    public init(
        network: GdkNetwork,
        popupResolver: PopupResolverDelegate? = nil,
        hwProtocol: HWProtocol? = nil,
        hwInterfaceResolver: HwInterfaceResolver? = nil,
        newNotificationDelegate: NewNotificationDelegate?
    ) {
        self.network = network
        self.accounts = []
        self.session = SessionManager(network.networkId)
        self.session.newNotificationDelegate = self
        self.session.popupResolver = popupResolver
        self.session.hwProtocol = hwProtocol
        self.session.hwInterfaceResolver = hwInterfaceResolver
        self.newNotificationDelegate = newNotificationDelegate
    }

    deinit {
        self.newNotificationDelegate = nil
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
        guard let res = try await session.subaccount(account.pointer) else {
            throw GaError.GenericError("No subaccount found for \(account.id)")
        }
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
        // Disable gdk login on multisig on new wallet
        if creation && network.multisig {
            return nil
        }
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
                refresh: refresh,
                hasGdkCache: hasGdkCache || network.multisig)
            _ = try? await session.loadSettings()
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

    func discoveryAndSetupDefaultsAccounts(walletHashId: String, refresh: Bool, hasGdkCache: Bool) async throws {
        let networkAccounts = try await getAccounts(refresh: refresh)
        let walletIsFunded = !networkAccounts.filter {
            $0.bip44Discovered == true
        }.isEmpty
        if walletIsFunded && refresh {
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
        } else if !hasGdkCache { // Newly discovered Wallet
            // Archive GDK default account
            logger.info("WM \(self.network.network) Archive GDK default account")
            if let defaultAccount = networkAccounts.first {
                _ = try await updateAccount(
                    account: defaultAccount,
                    name: defaultAccount.type.title,
                    hidden: true
                )
            }
        }
        // Create GDK bip84Segwit account
        let defaultAccountBip84 = networkAccounts.filter(
            {$0.type == .bip84Segwit
            }).first
        if defaultAccountBip84 == nil {
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
            self.block = block
            let minConfirmations = networkId.liquid ? 2 : 6
            Task { [weak self] in
                for accountBackend in (self?.accountBackends ?? [:]).values {
                    let pendingTxs = accountBackend.txs.values.filter {
                        $0.confirmations(block: block.height) <= minConfirmations
                    }
                    if !pendingTxs.isEmpty {
                        _ = try await accountBackend.getBalance(confirmations: 0)
                        _ = try await accountBackend
                            .getTransactions(
                                params: GetTransactionsParams(
                                    subaccount: accountBackend
                                        .account.pointer,
                                    first: 0,
                                    count: pendingTxs.count)
                            )
                    }
                }
                self?.newNotificationDelegate?
                    .didReceive(event: event, networkId: networkId)
            }
        case .newTransaction(let tx):
            logger
                .info(
                    "GdkNetworkBackend didReceive newTransaction(\(tx.txHash ?? "", privacy: .public)) on \(networkId.network, privacy: .public)"
                )
            Task { [weak self] in
                for accountBackend in (self?.accountBackends ?? [:]).values {
                    if let subaccounts = tx.subAccounts, subaccounts
                        .contains(accountBackend.account.pointer) {
                        _ = try await accountBackend.getBalance(confirmations: 0)
                        _ = try await accountBackend
                            .getTransactions(
                                params: GetTransactionsParams(
                                    subaccount: accountBackend
                                        .account.pointer,
                                    first: 0,
                                    count: 1)
                            )
                    }
                }
                self?.newNotificationDelegate?
                    .didReceive(event: event, networkId: networkId)
            }
        case .twoFactorReset:
            logger
                .info(
                    "GdkNetworkBackend didReceive twoFactorReset on \(networkId.network)"
                )
            Task { [weak session, weak newNotificationDelegate] in
                _ = try await session?.loadSettings()
                try await session?.loadTwoFactorConfig()
                newNotificationDelegate?
                    .didReceive(event: event, networkId: networkId)
            }
        case .updateSettings:
            logger
                .info(
                    "GdkNetworkBackend didReceive updateSettings on \(networkId.network)"
                )
            Task { [weak session, weak newNotificationDelegate] in
                _ = try await session?.loadSettings()
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
            newNotificationDelegate?
                .didReceive(event: event, networkId: networkId)
        default:
            break
        }
    }
}
