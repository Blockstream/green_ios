import core
import Foundation

@MainActor
class TFALimitViewModel {

    let mainWallet: Wallet
    let wm: WalletManager
    let networkId: NetworkId

    var backend: GdkNetworkBackend? { wm.gdkNetworkBackendOrNil(networkId) }
    var limits: TwoFactorConfigLimits? { backend?.twoFactorConfig?.limits }
    var denomination: DenominationType {
        backend?.settings?.denomination ?? .BTC
    }
    var isFiat: Bool { limits?.isFiat ?? false }
    var satoshi: Int64?

    internal init(mainWallet: Wallet, wm: WalletManager, networkId: NetworkId) {
        self.mainWallet = mainWallet
        self.wm = wm
        self.networkId = networkId
    }

    func setSatoshi(amount: String) {
        var amount = amount.isEmpty ? "0" : amount
        amount = amount.unlocaleFormattedString(8)
        guard let number = Double(amount), number >= 0 else { return }
        if isFiat {
            satoshi = Balance.fromFiat(amount, assetId: AssetInfo.btcId)?.satoshi
        } else {
            let assetId = networkId.gdkNetwork.getFeeAsset()
            satoshi = Balance.from(amount, assetId: assetId)?.satoshi
        }
    }

    func setTwoFactorLimit() async throws {
        try await backend?.setTwoFactorLimit(TwoFactorConfigLimits(isFiat: isFiat, satoshi: satoshi))
    }
}
