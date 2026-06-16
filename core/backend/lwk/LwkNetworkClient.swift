import Foundation
import LiquidWalletKit

class LwkNetworkClient {

    public static let BIP44_GAP_LIMIT = 20
    public static let WATERFALLS_URL_MAINNET = "https://waterfalls.liquidwebwallet.org/liquid/api"
    public static let WATERFALLS_URL_TESTNET = "https://waterfalls.liquidwebwallet.org/liquidtestnet/api"

    let isTestnet: Bool
    private let lwkNetwork: LiquidWalletKit.Network
    private let waterfallsUrl: String

    private enum ClientType {
        case esplora(EsploraClient)
        case electrum(ElectrumClient)
    }
    enum ClientBackend: String, CaseIterable {
        case waterfalls
        case esplora
        case electrum
    }

    private var clients: [ClientBackend: ClientType]

    init(isTestnet: Bool) {
        self.isTestnet = isTestnet
        self.lwkNetwork = isTestnet ? LiquidWalletKit.Network.testnet() : LiquidWalletKit.Network.mainnet()
        self.waterfallsUrl = isTestnet ? Self.WATERFALLS_URL_TESTNET : Self.WATERFALLS_URL_MAINNET
        self.clients = [:]
    }

    private func getClient(for backend: ClientBackend) async throws -> ClientType {
        if let client = clients[backend] {
            return client
        } else {
            let client = try await createClient(for: backend)
            clients[backend] = client
            return client
        }
    }

    private func createClient(for backend: ClientBackend) async throws -> ClientType {
        switch backend {
        case .esplora:
            return .esplora(try lwkNetwork.defaultEsploraClient())
        case .electrum:
            return .electrum(try lwkNetwork.defaultElectrumClient())
        case .waterfalls:
            return .esplora(
                try EsploraClient
                    .newWaterfalls(url: waterfallsUrl, network: lwkNetwork))
        }
    }

    func fullScanToIndex(wollet: LiquidWalletKit.Wollet, index: Int = BIP44_GAP_LIMIT) async throws -> Update? {
        return try await attemptClient(op: "fullScanToIndex") { esplora in
            return try esplora
                .fullScanToIndex(wollet: wollet, index: UInt32(index))
        } electrumClient: { electrum in
            return try electrum
                .fullScanToIndex(wollet: wollet, index: UInt32(index))
        }
    }

    func broadcast(tx: LiquidWalletKit.Transaction) async throws -> Txid {
        return try await attemptClient(op: "broadcast") { esplora in
            return try esplora.broadcast(tx: tx)
        } electrumClient: { electrum in
            return try electrum.broadcast(tx: tx)
        }
    }

    func tip() async throws -> BlockHeader {
        return try await attemptClient(op: "tip") { esplora in
            return try esplora.tip()
        } electrumClient: { electrum in
            return try electrum.tip()
        }
    }

    private func attemptClient<T>(
        op: String,
        timeoutMs: UInt64 = 120_000,
        esploraClient: @escaping (EsploraClient) throws -> T,
        electrumClient: @escaping (ElectrumClient) throws -> T
    ) async throws -> T {
        var lastError: Error?
        for backend in ClientBackend.allCases {
            let client = try await getClient(for: backend)
            // Check structured concurrency cancellation state before running next provider fallback
            try Task.checkCancellation()
            do {
                print("\(op) via \(backend.rawValue)")
                switch client {
                case .esplora(let instance):
                    return try esploraClient(instance)
                case .electrum(let instance):
                    return try electrumClient(instance)
                }
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
