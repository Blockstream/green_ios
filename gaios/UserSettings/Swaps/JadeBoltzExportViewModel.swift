import Foundation
import core
import hw


class JadeBoltzExportViewModel {
    let wm: WalletManager
    let mainWallet: Wallet

    var onReload: (() -> Void)?
    var onError: ((Error) -> Void)?

    var showQR: Bool { bcurParts == nil || privateKey == nil }
    var bcurParts: BcurEncodedData?
    var privateKey: Data?
    var credentials: Credentials?

    init(wallet: WalletManager, mainWallet: Wallet) {
        self.wm = wallet
        self.mainWallet = mainWallet
    }

    func performRequest() async {
        do {
            let session = wm.prominentSession
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
            let lightningMnemonic = await wm.prominentSession.jadeBip8539Reply(
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
        try AuthenticationTypeHandler.setCredentials(method: .AuthKeyBoltz, credentials: credentials, for: mainWallet.keychain)
    }

    func loginBoltz() async throws {
        guard let credentials else {
            throw HWError.Abort("No credentials found")
        }
        let xpubHashId = WalletsStorage.shared.current?.xpubHashId
        wm.loginLwkBoltz(boltzCredentials: credentials, xpubHashId: xpubHashId!)
        _ = await wm.awaitLwkSession()
    }

    nonisolated func request(session: SessionManager) async throws -> (Data?, BcurEncodedData?) {
        return try await session.jadeBip8539Request(index: LwkBoltzBackend.BOLTZ_BIP85_INDEX)
    }

    nonisolated func startSwapMonitor() async throws {
            let liquidAddress = await getAddress(subaccount: wm.liquidSubaccounts.first)
            let bitcoinAddress = await getAddress(subaccount: wm.bitcoinSubaccounts.first)
            if let liquidAddress, let bitcoinAddress {
                try? await wm.swapMonitor?.restoreSwaps(bitcoinAddress: bitcoinAddress, liquidAddress: liquidAddress)
            }
        try await wm.swapMonitor?.start()
    }

    nonisolated func getAddress(subaccount: Account?) async -> String? {
        guard let subaccount else { return nil }
        let backend = try? wm.gdkAccountBackend(subaccount)
        let address = try? await backend?.getReceiveAddress()
        return address?.address
    }
}
