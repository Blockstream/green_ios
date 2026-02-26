import LiquidWalletKit
import core
import gdk

actor QuoteBuilder {
    let boltzSession: BoltzSession
    var needRefresh = true
    init(boltzSession: BoltzSession) {
        self.boltzSession = boltzSession
    }
    func quote(
        amount: UInt64,
        mode: SwapPositionEnum,
        from: SwapAsset,
        to: SwapAsset)
    async throws -> Quote? {
        if needRefresh {
            do {
                try boltzSession.refreshSwapInfo()
                needRefresh = false
            } catch {
                throw error
            }
        }
        let builder = {
            switch mode {
            case .from:
                return boltzSession.quote(sendAmount: amount)
            case .to:
                return boltzSession.quoteReceive(receiveAmount: amount)
            }
        }()
        try builder.send(asset: from )
        try builder.receive(asset: to)
        return try builder.build()
    }
}
