import Foundation
import gdk
import core
import greenaddress
import hw

struct JadeBoltzSwapViewModel {

    let wm: WalletManager
    let mainAccount: Account

    init(wallet: WalletManager, mainAccount: Account) {
        self.wm = wallet
        self.mainAccount = mainAccount
    }

    func getBoltzKey() throws -> Credentials {
        try AuthenticationTypeHandler.getCredentials(method: .AuthKeyBoltz, for: mainAccount.keychain)
    }

    func existBoltzKey() -> Bool {
        (try? getBoltzKey()) != nil
    }

    func removeBoltzKey() throws {
        if AuthenticationTypeHandler.removeAuth(method: .AuthKeyBoltz, for: mainAccount.keychain) == false {
            throw HWError.Abort("id_operation_failure".localized)
        }
    }
    func existPendingSwap() async -> Bool {
        let swaps = try? await BoltzController.shared.fetchPendingSwaps(xpubHashId: mainAccount.xpubHashId ?? "")
        return swaps?.count ?? 0 > 0
    }
    func disconnectBoltz() async throws {
        try await wm.lwkSession?.disconnect()
    }
    
}
