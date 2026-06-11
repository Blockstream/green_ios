import Foundation
import gdk

public class WalletsRepository {

    public static let shared = WalletsRepository()

    // Store all the Wallet available for each account id
    public var wallets = [String: WalletManager]()

    public func add(for wallet: Wallet, wm: WalletManager? = nil) {
        if let wm = wm {
            wallets[wallet.id] = wm
            return
        }
        let wm = WalletManager(prominentNetwork: wallet.networkType)
        wallets[wallet.id] = wm
    }

    public func get(for walletId: String) -> WalletManager? {
        return wallets[walletId]
    }

    public func get(for wallet: Wallet) -> WalletManager? {
        get(for: wallet.id)
    }

    public func getOrAdd(for wallet: Wallet) -> WalletManager {
        if !wallets.keys.contains(wallet.id) {
            add(for: wallet)
        }
        return get(for: wallet)!
    }

    public func delete(for walletId: String) {
        wallets.removeValue(forKey: walletId)
    }

    public func delete(for wallet: Wallet?) {
        if let wallet = wallet {
            delete(for: wallet.id)
        }
    }

    public func delete(for wm: WalletManager) {
        if let index = wallets.firstIndex(where: { $0.value === wm }) {
            wallets.remove(at: index)
        }
    }
}
