import Foundation
import core

class SupportManager {

    static let shared = SupportManager()

    func str() async -> String {
        let multiSigSessions = { WalletManager.current?.activeLiquidBackends.filter { !$0.network.electrum && !$0.network.lightning} }()
        let msMainSession = multiSigSessions?.filter { !$0.network.liquid }.first
        let msLiquidSession = multiSigSessions?.filter { $0.network.liquid }.first
        var strings: [String] = []

        if let item = try? await msMainSession?.accounts.first {
            strings.append("bitcoin:\(item.receivingId)")
        }
        if let item = try? await msLiquidSession?.accounts.first {
            strings.append("liquidnetwork:\(item.receivingId)")
        }
        if let nodeId = WalletManager.current?.lightningSession?.nodeState()?.id {
            strings.append("lightning:\(nodeId)")
        }
        return strings.joined(separator: ",")
    }
}
