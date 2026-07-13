import Foundation
import lightning
import Combine
import greenaddress
import hw

public final class GlNetworkBackend: NetworkBackend {

    public let network: GdkNetwork
    public private(set) var session: LightningSessionManager
    public private(set) var accounts: [Account]
    public private(set) var block: Block?

    public var isConnected: Bool { session.connected }
    public var isLoggedIn: Bool { session.logged }
    public var isWatchOnly = false
    public var authenticationRequired = false
    public var gdkNetwork: GdkNetwork { network }
    public var networkId: NetworkId { network.networkId }

    public let account: Account
    private var accountBackends = [String: AccountBackend]()
    public weak var newNotificationDelegate: NewNotificationDelegate?

    public init(
        network: GdkNetwork,
        newNotificationDelegate: NewNotificationDelegate?
    ) {
        self.network = network
        self.newNotificationDelegate = newNotificationDelegate
        self.session = LightningSessionManager(network: network)
        let partialAccount = Account(
            gdkName: "",
            pointer: 0,
            type: .lightning,
            networkInjected: network
        )
        self.account = partialAccount
        self.accounts = [partialAccount]
        self.session.setNotificationDelegate(self)
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
        return GlAccountBackend(
            networkBackend: self,
            account: account,
            session: session
        )
    }
    public func createAccount(params: CreateSubaccountParams) async throws -> Account {
        throw GaError.GenericError("Can't create a Lightning account")
    }

    public func isPolicyAsset(assetId: String?) -> Bool {
        return assetId == AssetInfo.lightningId
    }

    public func connect(params: ConnectionParams) async throws {
    }

    public func isAddressValid(address: String) async throws -> Bool {
        throw GaError.GenericError("Not implemented")
    }

    public func getAccounts(refresh: Bool) async throws -> [Account] {
        guard isLoggedIn else { return [] }
        return accounts
    }

    public func getAccount(account: Account) async throws -> Account {
        return account
    }

    public func disconnect() async throws {
        await session.disconnect()
    }

    public func broadcastTransaction(broadcastTransaction: BroadcastTransactionParams) async throws -> SendTransactionSuccess {
        throw GaError.GenericError("Not implemented")
    }

    public func login(
        credentials: Credentials,
        isForceConnectAllowed: Bool,
        parentXpub: String
    ) async throws {

        let lightningCredentials = LightningRepository.shared.get(
            for: parentXpub
        )
        let glCredentials = GreenlightMnemonicAndCredentials(
            mnemonic: credentials.mnemonic!,
            credentials: lightningCredentials?.credentials
        )
        let workingDir = try LightningSessionManager
            .workingDir(xpub: parentXpub)
            .path()
        let newLightningCredentials = try await session.loginUser(params: glCredentials, workingDir: workingDir, isForceConnectAllowed: isForceConnectAllowed)
        if let newLightningCredentials {
            LightningRepository.shared
                .upsert(
                    for: parentXpub,
                    credentials: newLightningCredentials)
        }
    }
}

extension GlNetworkBackend: NewNotificationDelegate {
    public func didReceive(
        event: EventNotificationTypes,
        networkId: NetworkId
    ) {
        switch event {
        case .invoicePaid(let details):
            logger
                .info(
                    "GlNetworkBackend didReceive invoicePaid(\(details.paymentHash)) on \(networkId.network)"
                )
            Task { [weak self] in
                guard let self else { return }
                _ = try await self
                    .accountBackend(self.account)
                    .getBalance(confirmations: 0)
                _ = try await accountBackend(self.account)
                    .getTransactions(
                        params: GetTransactionsParams(subaccount: 0)
                    )
                newNotificationDelegate?.didReceive(
                    event: .invoicePaid(details),
                    networkId: networkId
                )
            }
        default:
            break
        }
    }
}
