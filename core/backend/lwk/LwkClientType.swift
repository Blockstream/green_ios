import Foundation
import LiquidWalletKit

public enum LwkClientType {

    public static let BIP44_GAP_LIMIT = 20

    case waterfalls(WaterfallsClient)
    case esplora(EsploraClient)
    case electrum(ElectrumClient)

    func tip() async throws -> BlockHeader {
        switch self {
        case .waterfalls(let client):
            return try client.tip()
        case .esplora(let client):
            return try client.tip()
        case .electrum(let client):
            return try client.tip()
        }
    }

    func fullScanToIndex(wollet: LiquidWalletKit.Wollet, index: Int = BIP44_GAP_LIMIT) async throws -> Update? {
        switch self {
        case .waterfalls(let client):
            return try client.fullScanToIndex(wollet: wollet, index: UInt32(index))
        case .esplora(let client):
            return try client.fullScanToIndex(wollet: wollet, index: UInt32(index))
        case .electrum(let client):
            return try client.fullScanToIndex(wollet: wollet, index: UInt32(index))
        }
    }

    func broadcast(tx: LiquidWalletKit.Transaction) async throws -> Txid {
        switch self {
        case .waterfalls(let client):
            return try client.broadcast(tx: tx)
        case .esplora(let client):
            return try client.broadcast(tx: tx)
        case .electrum(let client):
            return try client.broadcast(tx: tx)
        }
    }
}
