import Foundation
import gdk
import core
import greenaddress

struct LTCreateViewModel {
    var mainAccount: Account
    var wallet: WalletDataModel
    var isHW: Bool { mainAccount.isHW }

    init(mainAccount: Account, wallet: WalletDataModel) {
        self.wallet = wallet
        self.mainAccount = mainAccount
    }

    func enableLightning() async throws {
        guard let credentials = try await wallet.wallet.prominentSession?.getCredentials(password: "") else {
            throw GaError.GenericError("Invalid credentials")
        }
        let lightningCredentials = try await wallet.wallet.deriveLightningCredentials(from: credentials)
        // Get lightning session
        guard let session = await wallet.wallet.lightningSession else {
            throw GaError.GenericError("Invalid lightning session")
        }
        // remove previous lightning data
        await session.removeDatadir(credentials: lightningCredentials)
        // connect lightning session
        await session.connect()
        _ = try await session.loginUser(lightningCredentials)
        // Add auth into keychain
        try AuthenticationTypeHandler
            .setCredentials(
                method: .AuthKeyLightning,
                credentials: lightningCredentials,
                for: mainAccount.keychainLightning
            )
        
        // Register device to receive notifications
        let token = UserDefaults(suiteName: Bundle.main.appGroup)?.string(forKey: "token") ?? ""
        if !token.isEmpty, let xpubHashId = mainAccount.xpubHashId {
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
