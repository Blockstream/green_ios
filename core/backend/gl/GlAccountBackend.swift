import Foundation
import greenaddress
import hw

public final class GlAccountBackend: AccountBackend {

    // MARK: - Properties
    public let session: LightningSessionManager
    public let account: Account
    public private(set) var assets: Assets = [:]
    public private(set) var txs = [String: Transaction]()
    public var hasTxs: Bool { !txs.isEmpty }
    public weak var networkBackend: GlNetworkBackend?

    var network: GdkNetwork {
        return account.network
    }

    // MARK: - Initializer
    init(
        networkBackend: GlNetworkBackend,
        account: Account,
        session: LightningSessionManager
    ) {
        self.networkBackend = networkBackend
        self.account = account
        self.session = session
    }

    public func getReceiveAddress() async throws -> Address {
        try await session.getReceiveAddress(subaccount: account.pointer)
    }

    public func getBalance(confirmations: Int = 0) async throws -> [String: Int64] {
        let res = try await session.getBalance(subaccount: account.pointer, numConfs: 0)
        if confirmations == 0 {
            self.assets = res
        }
        return res
    }

    public func getTransactions(params: GetTransactionsParams) async throws -> Transactions {
        let res = try await session.transactions(params)
        for tx in res.list {
            if let paymentPreimage = tx.paymentPreimage {
                txs[paymentPreimage] = tx
            }
        }
        return res
    }

    public func getOutputDescriptors() async throws -> String? {
        session.nodeState()?.id
    }

    public func getUnspentOutputs(isBump: Bool, isExpired: Bool, expiredAt: UInt64?) async throws -> [String: [UnspentOutput]] {
        return ["":[]]
    }

    public func createTransaction(params: Transaction) async throws -> Transaction {
        return try await session.createTransaction(tx: params)
    }

    public func signTransaction(createTransaction: Transaction) async throws -> Transaction {
        return try await session.signTransaction(tx: createTransaction)
    }
}
