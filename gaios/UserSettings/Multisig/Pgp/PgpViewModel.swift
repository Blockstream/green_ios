import Foundation
import UIKit
import core

class PgpViewModel {

    let mainWallet: Wallet
    let manager: WalletManager
    var networkIds: [NetworkId] {
        manager.activeGdkMultisigNetworkIds
    }
    var backends: [GdkNetworkBackend] {
        networkIds.map { manager.gdkNetworkBackendOrNil($0) }.compactMap { $0 }
    }
    var pgp: String? {
        backends
            .compactMap { $0.settings?.pgp }
            .filter { !$0.isEmpty }
            .first
    }

    internal init(mainWallet: Wallet, manager: WalletManager) {
        self.mainWallet = mainWallet
        self.manager = manager
    }

    func getPgp() -> String? {
        return pgp
    }

    func setPgp(pgp: String) async throws {
        guard var settings = manager.settings else { return }
        settings.pgp = pgp
        for backend in backends {
            try await backend.changeSettings(settings)
        }
    }
}
