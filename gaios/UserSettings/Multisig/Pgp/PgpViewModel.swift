import Foundation
import UIKit
import core

class PgpViewModel {

    let mainWallet: Wallet
    let manager: WalletManager
    let networkId: NetworkId

    var backend: GdkNetworkBackend? {
        manager.gdkNetworkBackendOrNil(networkId)
    }

    internal init(mainWallet: Wallet, manager: WalletManager, networkId: NetworkId) {
        self.mainWallet = mainWallet
        self.manager = manager
        self.networkId = networkId
    }

    func getPgp() -> String? {
        return backend?.settings?.pgp
    }

    func setPgp(pgp: String) async throws {
        guard var settings = backend?.settings else { return }
        settings.pgp = pgp
        try await backend?.changeSettings(settings)
    }
}
