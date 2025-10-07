import Foundation
import gdk
import core
import greenaddress

struct LTCreateViewModel {
    var wallet: WalletManager? { WalletManager.current }
    var mainAccount: Account? { AccountsRepository.shared.current }
    var isHW: Bool { wallet?.isHW ?? false }

    func enableLightning() async throws {
        guard let account = mainAccount else {
            throw GaError.GenericError("Invalid account")
        }
        guard let credentials = try await wallet?.prominentSession?.getCredentials(password: "") else {
            throw GaError.GenericError("Invalid credentials")
        }
        guard let lightningCredentials = try wallet?.deriveLightningCredentials(from: credentials) else {
            throw GaError.GenericError("Invalid credentials")
        }
        // Get lightning session
        guard let session = wallet?.lightningSession else {
            throw GaError.GenericError("Invalid lightning session")
        }
        // remove previous lightning data
        await session.removeDatadir(credentials: lightningCredentials)
        // connect lightning session
        try await session.connect()
        _ = try await session.loginUser(lightningCredentials)
        if let token = UserDefaults(suiteName: Bundle.main.appGroup)?.string(forKey: "token"),
           let xpubHashId = account.xpubHashId {
            try? await session.registerNotification(token: token, xpubHashId: xpubHashId)
        }
        _ = session.lightBridge?.updateLspInformation()
        _ = try await wallet?.subaccounts()
        // Add auth into keychain
        try AuthenticationTypeHandler.setCredentials(method: .AuthKeyLightning, credentials: lightningCredentials, for: account.keychainLightning)
    }
}
