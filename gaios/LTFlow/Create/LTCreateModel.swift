import Foundation

import core
import greenaddress

struct LTCreateViewModel {
    var mainWallet: Wallet
    var wallet: WalletDataModel
    var isHW: Bool { mainWallet.isHW }

    init(mainWallet: Wallet, wallet: WalletDataModel) {
        self.wallet = wallet
        self.mainWallet = mainWallet
    }

    func enableLightning() async throws {
        guard let credentials = try await wallet.wallet.prominentSession.getCredentials(password: "") else {
            throw GaError.GenericError("Invalid credentials")
        }
        guard let xpubHashId = mainWallet.xpubHashId else {
            throw GaError.GenericError("Invalid xpub")
        }
        let walletManager = await wallet.wallet
        let lightningCredentials = try walletManager.deriveLightningCredentials(from: credentials)
        // remove previous lightning data
            if let workingDir = try? LightningSessionManager.workingDir(xpub: xpubHashId) {
                try? walletManager.removeDatadir(workingDir.path())
            }
        let backend = try walletManager.glNetworkBackend()
        try await backend.login(credentials: lightningCredentials, isForceConnectAllowed: true, parentXpub: xpubHashId)
        // Get lightning session
        guard let session = await wallet.wallet.lightningSession else {
            throw GaError.GenericError("Invalid lightning session")
        }
        // Add auth into keychain
        try AuthenticationTypeHandler
            .setCredentials(
                method: .AuthKeyLightning,
                credentials: lightningCredentials,
                for: mainWallet.keychainLightning
            )
        // Register device to receive notifications
        let token = UserDefaults(suiteName: Bundle.main.appGroup)?.string(forKey: "token") ?? ""
        if !token.isEmpty, let xpubHashId = mainWallet.xpubHashId {
            try? await session.registerNotification(fcmToken: token, xpubHashId: xpubHashId)
        }
        // Update subaccounts and UI
        await wallet.triggerRefresh(
                features: [.subaccounts]
            )
        await wallet
            .triggerRefresh(
                features: [.balance, .txs(reset: true)]
            )
    }
}
