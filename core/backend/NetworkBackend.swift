import Foundation

public protocol NetworkBackend: AnyObject {
    var network: GdkNetwork { get }
    var networkId: NetworkId { get }
    var isConnected: Bool { get }
    var isLoggedIn: Bool { get }
    var accounts: [Account] { get }
    var block: Block? { get }

    // Flows migrated to AsyncStreams for Swift 6 structured concurrency
    //var networkEvents: NetworkEvent? { get }
    //var block: Block? { get }
    //var networkEventsStream: AsyncStream<NetworkEvent> { get }
    //var blockStateStream: AsyncStream<Block> { get }
    //var accountsStream: AsyncStream<[Account]> { get }

    func accountBackend(_ account: Account) throws -> AccountBackend
    func isPolicyAsset(assetId: String?) -> Bool
    func connect(params: ConnectionParams) async throws
    func isAddressValid(address: String) async throws -> Bool
    func getAccounts(refresh: Bool) async throws -> [Account]
    func getAccount(account: Account) async throws -> Account

    func disconnect() async throws
    func createAccount(params: CreateSubaccountParams) async throws -> Account

    func broadcastTransaction(broadcastTransaction: BroadcastTransactionParams) async throws -> SendTransactionSuccess
}
