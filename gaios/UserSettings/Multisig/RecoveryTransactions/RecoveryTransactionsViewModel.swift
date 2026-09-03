import Foundation
import UIKit
import core

class RecoveryTransactionsViewModel {

    let mainWallet: Wallet
    let manager: WalletManager
    let networkId: NetworkId

    var backend: GdkNetworkBackend? {
        manager.gdkNetworkBackendOrNil(networkId)
    }
    var twoFactorConfig: TwoFactorConfig? {
        backend?.twoFactorConfig
    }

    var getTwoFactorItemEmail: TwoFactorItem? {
        guard let twoFactorConfig else { return nil }
        return TwoFactorItem(
            name: "id_email".localized,
            enabled: twoFactorConfig.email.enabled,
            confirmed: twoFactorConfig.email.confirmed,
            maskedData: twoFactorConfig.email.data,
            type: TwoFactorType.email)
    }

    internal init(mainWallet: Wallet, manager: WalletManager, networkId: NetworkId) {
        self.mainWallet = mainWallet
        self.manager = manager
        self.networkId = networkId
    }

    func enableRecoveryTransactions(enable: Bool) async throws {
        if var settings = backend?.settings {
            settings.notifications = SettingsNotifications(
                emailIncoming: enable,
                emailOutgoing: enable)
            try await backend?.changeSettings(settings)
        }
    }

    func sendNlocktimes() async throws {
        try await backend?.sendNlocktimes()
    }
}
