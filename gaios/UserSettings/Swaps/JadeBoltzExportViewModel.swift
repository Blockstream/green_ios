import Foundation
import core
import hw
import gdk

class JadeBoltzExportViewModel {
    let wm: WalletManager
    let mainAccount: Account

    var onReload: (() -> Void)?
    var onError: ((Error) -> Void)?

    var showQR: Bool { bcurParts == nil || privateKey == nil }
    var bcurParts: BcurEncodedData?
    var privateKey: Data?
    var credentials: Credentials?

    init(wallet: WalletManager, mainAccount: Account) {
        self.wm = wallet
        self.mainAccount = mainAccount
    }

    func performRequest() async {
        do {
            guard let session = wm.prominentSession else { return }
            let (privateKey, bcurParts) = try await request(session: session)
            self.privateKey = privateKey
            self.bcurParts = bcurParts
            onReload?()
        } catch {
            onError?(error)
        }
    }

    func performReply(publicKey: String, encrypted: String) async {
        guard let privateKey = privateKey else {
            onError?(HWError.Abort("Invalid private key"))
            return
        }
            let lightningMnemonic = await wm.prominentSession?.jadeBip8539Reply(
                privateKey: privateKey,
                publicKey: publicKey.hexToData(),
                encrypted: encrypted.hexToData())
            guard let lightningMnemonic else {
                onError?(HWError.Abort("Invalid key derivation"))
                return
            }
            credentials = Credentials(mnemonic: lightningMnemonic)
            onReload?()
    }

    func performStoreKey() throws {
        guard let credentials = credentials else {
            throw HWError.Abort("No credentials found")
        }
        try AuthenticationTypeHandler.setCredentials(method: .AuthKeyBoltz, credentials: credentials, for: mainAccount.keychain)
    }

    func loginBoltz() async throws {
        guard let credentials, let lwkSession = wm.lwkSession else {
            throw HWError.Abort("No credentials found")
        }
        _ = try await wm.loginLWK(lwk: lwkSession, credentials: credentials, parentWalletId: mainAccount.walletIdentifier)
    }

    nonisolated func request(session: SessionManager) async throws -> (Data?, BcurEncodedData?) {
        return try await session.jadeBip8539Request(index: LwkSessionManager.BOLTZ_BIP85_INDEX)
    }
}
