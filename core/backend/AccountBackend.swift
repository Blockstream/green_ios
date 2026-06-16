import Foundation

public protocol AccountBackend: AnyObject {
    var account: Account { get }
    var assets: Assets { get }
    var txs: [String: Transaction] { get }
    var hasTxs: Bool { get }

    func getReceiveAddress() async throws -> Address
    func getBalance(confirmations: Int) async throws -> [String: Int64]
    func getTransactions(params: GetTransactionsParams) async throws -> Transactions
    func getOutputDescriptors() async throws -> String?
    func getUnspentOutputs(isBump: Bool, isExpired: Bool, expiredAt: UInt64?) async throws -> [String: [UnspentOutput]]
    func createTransaction(params: Transaction) async throws -> Transaction
    func signTransaction(createTransaction: Transaction) async throws -> Transaction
}
