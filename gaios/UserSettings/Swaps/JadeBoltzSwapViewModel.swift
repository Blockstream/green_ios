import Foundation
import gdk
import core
import greenaddress
import hw

struct JadeBoltzSwapViewModel {

    let wm: WalletManager
    let mainWallet: Wallet

    init(wallet: WalletManager, mainWallet: Wallet) {
        self.wm = wallet
        self.mainWallet = mainWallet
    }

    func getBoltzKey() throws -> Credentials {
        try AuthenticationTypeHandler.getCredentials(method: .AuthKeyBoltz, for: mainWallet.keychain)
    }

    func existBoltzKey() -> Bool {
        (try? getBoltzKey()) != nil
    }

    func removeBoltzKey() throws {
        if AuthenticationTypeHandler.removeAuth(method: .AuthKeyBoltz, for: mainWallet.keychain) == false {
            throw HWError.Abort("id_operation_failure".localized)
        }
    }
    func existPendingSwap() async -> Bool {
        let swaps = try? await BoltzController.shared.fetchPendingSwaps(xpubHashId: mainWallet.xpubHashId ?? "")
        return swaps?.count ?? 0 > 0
    }
    func disconnectBoltz() async throws {
        try await wm.lwkSession?.disconnect()
    }
    
}
