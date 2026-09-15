import Foundation
import core
import hw


class LTExportJadeViewModel {
    private var wm: WalletManager? { WalletManager.current }
    private var mainWallet: Wallet? { WalletsStorage.shared.current }
    private var privateKey: Data?
    private var wallet: WalletDataModel

    init(wallet: WalletDataModel) {
        self.wallet = wallet
    }

    func request() async throws -> BcurEncodedData? {
        guard let session = wm?.prominentSession else { return nil }
        let (privateKey, bcurParts) = try await session.jadeBip8539Request(index: 0)
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

    func enableLightning(lightningCredentials: Credentials) async throws -> Account {
        // Get lightning session
        guard let walletManager = wm, let mainWallet else {
            throw HWError.Abort("Invalid lightning session")
        }
        guard let xpubHashId = mainWallet.xpubHashId else {
            throw HWError.Abort("Invalid xpub")
        }
        // remove previous lightning data
        if let workingDir = try? LightningSessionManager.workingDir(xpub: xpubHashId) {
            try? walletManager.removeDatadir(workingDir.path())
        }
        let backend = try walletManager.glNetworkBackend()
        _ = try await backend
            .login(
                credentials: lightningCredentials,
                restore: false,
                parentXpub: xpubHashId
            )
        guard let account = try await backend.getAccounts(refresh: false).first else {
            throw HWError.Abort("Lightning account not available")
        }
        // Add auth into keychain
        try AuthenticationTypeHandler.setCredentials(method: .AuthKeyLightning, credentials: lightningCredentials, for: mainWallet.keychainLightning)
        // Register device to receive notifications
        let token = UserDefaults(suiteName: Bundle.main.appGroup)?.string(forKey: "token") ?? ""
        if !token.isEmpty, let xpubHashId = mainWallet.xpubHashId {
            try? await backend.session.registerNotification(fcmToken: token, xpubHashId: xpubHashId)
        }
        // Update subaccounts and UI
        await wallet.triggerRefresh(features: [.subaccounts])
        await wallet.triggerRefresh(features: [.balance, .txs(reset: true)])
        return account
    }
}
