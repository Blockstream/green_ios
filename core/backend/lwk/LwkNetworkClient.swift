import Foundation
import LiquidWalletKit

class LwkNetworkClient {

    public static let BIP44_GAP_LIMIT = 20
    public static let WATERFALLS_URL_MAINNET = "https://waterfalls.liquidwebwallet.org/liquid/api"
    public static let WATERFALLS_URL_TESTNET = "https://waterfalls.liquidwebwallet.org/liquidtestnet/api"

    let isTestnet: Bool
    private let lwkNetwork: LiquidWalletKit.Network

    enum ClientBackend: String, CaseIterable {
        case waterfalls
        case esplora
        case electrum
    }

    private var clients: [ClientBackend: LwkClientType]

    init(isTestnet: Bool) {
        self.isTestnet = isTestnet
        self.lwkNetwork = isTestnet ? LiquidWalletKit.Network.testnet() : LiquidWalletKit.Network.mainnet()
        self.clients = [:]
    }

    private func getClient(for backend: ClientBackend) async throws -> LwkClientType {
        if let client = clients[backend] {
            return client
        } else {
            let client = try await createClient(for: backend)
            clients[backend] = client
            return client
        }
    }

    private func createClient(for backend: ClientBackend) async throws -> LwkClientType {
        switch backend {
        case .esplora:
            return .esplora(try lwkNetwork.defaultEsploraClient())
        case .electrum:
            return .electrum(try lwkNetwork.defaultElectrumClient())
        case .waterfalls:
            let waterfallsUrl = isTestnet ? Self.WATERFALLS_URL_TESTNET : Self.WATERFALLS_URL_MAINNET
            return .waterfalls(try WaterfallsClient(
                url: waterfallsUrl,
                network: lwkNetwork
            ))
        }
    }

    func fullScanToIndex(wollet: LiquidWalletKit.Wollet, index: Int = BIP44_GAP_LIMIT) async throws -> Update? {
        return try await attemptClient(op: "fullScanToIndex") { client in
            return try await client
                .fullScanToIndex(wollet: wollet, index: index)
        }
    }

    func broadcast(tx: LiquidWalletKit.Transaction) async throws -> Txid {
        return try await attemptClient(op: "broadcast") { client in
            return try await client.broadcast(tx: tx)
        }
    }

    func tip() async throws -> BlockHeader {
        return try await attemptClient(op: "tip") { client in
            return try await client.tip()
        }
    }

    private func attemptClient<T>(
        op: String,
        timeoutMs: UInt64 = 120_000,
        action: @escaping (LwkClientType) async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for backend in ClientBackend.allCases {
            do {
                let client = try await getClient(for: backend)
                // Check structured concurrency cancellation state before running next provider fallback
                try Task.checkCancellation()
                print("\(op) via \(backend.rawValue)")
                return try await action(client)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                print("LWK \(backend.rawValue) client failed: \(error.localizedDescription)")
                lastError = error
            }
        }

        throw lastError ?? NSError(domain: "LwkNetworkClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "\(op) failed: no client attempted"])
    }

}
