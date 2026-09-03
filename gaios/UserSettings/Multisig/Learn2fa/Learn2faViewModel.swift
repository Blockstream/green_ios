import Foundation
import core

class Learn2faViewModel {

    let mainWallet: Wallet
    let manager: WalletManager
    let networkId: NetworkId
    let message: TwoFactorResetMessage

    init(mainWallet: Wallet, manager: WalletManager, networkId: NetworkId, message: TwoFactorResetMessage) {
        self.mainWallet = mainWallet
        self.manager = manager
        self.networkId = networkId
        self.message = message
    }

    var backend: GdkNetworkBackend? {
        manager.gdkNetworkBackendOrNil(networkId)
    }

    var twofactorReset: TwoFactorReset? {
        self.backend?.twoFactorConfig?.twofactorReset
    }

}
