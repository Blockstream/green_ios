import Foundation
import greenaddress
import hw

public final class GdkAccountBackend: AccountBackend {

    // MARK: - Properties
    public let session: SessionManager
    public let account: Account
    public private(set) var assets: Assets = [:]
    public private(set) var txs = [String: Transaction]()
    public var hasTxs: Bool { !txs.isEmpty }
    public weak var networkBackend: GdkNetworkBackend?

    var network: GdkNetwork {
        return account.network
    }

    // MARK: - Initializer
    init(
        networkBackend: GdkNetworkBackend,
        account: Account,
        session: SessionManager
    ) {
        self.networkBackend = networkBackend
        self.account = account
        self.session = session
    }

    public func updateAccount(name: String? = nil, hidden: Bool? = nil) async throws {
        let params = UpdateSubaccountParams(
            subaccount: account.pointer,
            name: name,
            hidden: hidden
        )
        try await session.updateSubaccount(params)
    }

    public func getReceiveAddress() async throws -> Address {
        try await session.getReceiveAddress(subaccount: account.pointer)
    }

    public func getBalance(confirmations: Int = 0) async throws -> [String: Int64] {
        let res = try await session.getBalance(subaccount: account.pointer, numConfs: confirmations)
        if confirmations == 0 {
            self.assets = res
        }
        return res
    }

    public func getTransactions(params: GetTransactionsParams) async throws -> Transactions {
        let res = try await session.transactions(params)
        for tx in res.list {
            if let txHash = tx.hash {
                txs[txHash] = tx
            }
        }
        return res
    }

    public func getOutputDescriptors() async throws -> String? {
        let res = try await session.subaccount(account.pointer)
        return res?.outputDescriptors
    }

    public func getUnspentOutputs(isBump: Bool, isExpired: Bool, expiredAt: UInt64?) async throws -> [String: [UnspentOutput]] {
        let params: GetUnspentOutputsParams
        if isExpired {
            params = GetUnspentOutputsParams(
                subaccount: account.pointer,
                numConfs: 1,
                expiredAt: expiredAt
            )
        } else {
            params = GetUnspentOutputsParams(
                subaccount: account.pointer,
                numConfs: isBump ? 1 : 0
            )
        }
        return try await session.getUtxos(params).unspentOutputs
    }

    public func createTransaction(params: Transaction) async throws -> Transaction {
        return try await session.createTransaction(tx: params)
    }

    public func blindTransaction(params: Transaction) async throws -> Transaction {
        return try await session.blindTransaction(tx: params)
    }

    public func signTransaction(createTransaction: Transaction) async throws -> Transaction {
        return try await session.signTransaction(tx: createTransaction)
    }

    public func isFunded() -> Bool {
        assets.values.contains(where: { $0 > 0 })
    }

    public func hasHistory() async -> Bool {
        if account.bip44Discovered == true || isFunded() {
            return true
        }
        let params = GetTransactionsParams(
            subaccount: account.pointer,
            first: 0,
            count: 1
        )
        let txs = try? await getTransactions(params: params)
        return !(txs?.list ?? []).isEmpty
    }
}
