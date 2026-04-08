import Foundation
import gdk
import core
import lightning

struct LTRedeemViewModel {

    var wallet: WalletItem?
    var onChainAddress: String?
    var amount: UInt64?
    var txid: String?
    var error: String?
    var amountText: String { Balance.fromSatoshi(amount ?? 0, assetId: AssetInfo.btcId)?.toText() ?? "" }

    var fiatText: String { Balance.fromSatoshi(amount ?? 0, assetId: AssetInfo.btcId)?.toFiatText() ?? "" }

    mutating func redeem() async throws {
        guard let onChainAddress, let lightningSession = WalletManager.current?.lightningSession else {
            return
        }
        let res = try await lightningSession.redeemAllOnchainFunds(destination: onChainAddress)
        txid = res
        AnalyticsManager.shared.emptiedAccount = wallet
    }
}
