import Foundation
import gdk

public class WalletsRepository {

    public static let shared = WalletsRepository()

    // Store all the Wallet available for each account id
    public var wallets = [String: WalletManager]()

    public func add(for account: Account, wm: WalletManager? = nil) {
        if let wm = wm {
            wallets[account.id] = wm
            return
        }
        let wm = WalletManager(prominentNetwork: account.networkType)
        wallets[account.id] = wm
    }

    public func get(for accountId: String) -> WalletManager? {
        return wallets[accountId]
    }

    public func get(for account: Account) -> WalletManager? {
        get(for: account.id)
    }

    public func getOrAdd(for account: Account) -> WalletManager {
        if !wallets.keys.contains(account.id) {
            add(for: account)
        }
        return get(for: account)!
    }

    public func delete(for accountId: String) {
        wallets.removeValue(forKey: accountId)
    }

    public func delete(for account: Account?) {
        if let account = account {
            delete(for: account.id)
        }
    }

    public func delete(for wm: WalletManager) {
        if let index = wallets.firstIndex(where: { $0.value === wm }) {
            wallets.remove(at: index)
        }
    }

    public func change(wm: WalletManager, for account: Account) {
        delete(for: wm)
        add(for: account, wm: wm)
    }
}
