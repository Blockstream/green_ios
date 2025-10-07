import Foundation
import core
import hw
import gdk

class LTExportJadeViewModel {
    private var wm: WalletManager? { WalletManager.current }
    private var mainAccount: Account? { AccountsRepository.shared.current }
    private var privateKey: Data?

    func request() async -> BcurEncodedData? {
        guard let session = wm?.prominentSession else { return nil }
        let (privateKey, bcurParts) = await session.jadeBip8539Request()
        self.privateKey = privateKey
        return bcurParts
    }

    func reply(publicKey: String, encrypted: String) async throws -> Credentials {
        guard let session = wm?.prominentSession else {
            throw HWError.Abort("id_invalid_session".localized)
        }
        guard let privateKey = privateKey else {
            throw HWError.Abort("Invalid private key")
        }
        let lightningMnemonic = await session.jadeBip8539Reply(
            privateKey: privateKey,
            publicKey: publicKey.hexToData(),
            encrypted: encrypted.hexToData())
        guard let lightningMnemonic = lightningMnemonic else {
            throw HWError.Abort("Invalid key derivation")
        }
        return Credentials(mnemonic: lightningMnemonic)
    }
    
    func enableLightning(credentials: Credentials) async throws {
        // Get lightning session
        guard let session = wm?.lightningSession,
            let account = mainAccount else {
            throw HWError.Abort("Invalid lightning session")
        }
        // remove previous lightning data
        await session.removeDatadir(credentials: credentials)
        // connect lightning session
        try await session.connect()
        let _ = try await session.loginUser(credentials)
        if let token = UserDefaults(suiteName: Bundle.main.appGroup)?.string(forKey: "token"),
           let xpubHashId = account.xpubHashId {
            try? await session.registerNotification(token: token, xpubHashId: xpubHashId)
        }
        _ = session.lightBridge?.updateLspInformation()
        _ = try await wm?.subaccounts()
        // Add auth into keychain
        try AuthenticationTypeHandler.setCredentials(method: .AuthKeyLightning, credentials: credentials, for: account.keychainLightning)
    }
}
