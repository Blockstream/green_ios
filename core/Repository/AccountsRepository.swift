import Foundation
import gdk

public class AccountsRepository {

    let attrAccount = "AccountsManager_Account"
    let attrService = "AccountsManager_Service"

    public static let shared = AccountsRepository()
    let storage: KeychainStorage

    public init() {
        storage = KeychainStorage(account: attrAccount, service: attrService)
    }

    // List of saved accounts with cache
    private var accountsCached: [Account]?
    public var accounts: [Account] {
        get {
            if let cached = accountsCached {
                return cached
            }
            let data = try? storage.read()
            accountsCached = try? JSONDecoder().decode([Account].self, from: data ?? Data())
            return accountsCached ?? []
        }
        set {
            try? storage.write(newValue.encoded())
            accountsCached = newValue
        }
    }

    // Current Account
    private var currentId = ""
    public var current: Account? {
        get {
            get(for: currentId)
        }
        set {
            currentId = newValue?.id ?? ""
            if let account = newValue {
                upsert(account)
            }
        }
    }

    // Filtered account list of software wallets
    public var swAccounts: [Account] { accounts.filter { !$0.isHW } }

    // Filtered account list of software ephemeral wallets
    public var ephAccounts: [Account] = [Account]()

    // Filtered account list of hardware wallets
    public var hwAccounts: [Account] { accounts.filter { $0.isHW } }
    public var hwVisibleAccounts: [Account] { hwAccounts.filter { !($0.hidden ?? true) } }

    public func get(for id: String) -> Account? {
        ephAccounts.filter({ $0.id == id }).first ??
        accounts.filter({ $0.id == id }).first ??
        accounts.compactMap { $0.getDerivedLightningAccount() }.filter({ $0.id == id }).first
    }

    public func find(xpubHashId: String) -> [Account]? {
        ephAccounts.filter({ $0.xpubHashId == xpubHashId }) +
        accounts.filter({ $0.xpubHashId == xpubHashId }) +
        accounts.compactMap { $0.getDerivedLightningAccount() }.filter({ $0.xpubHashId == xpubHashId })
    }

    public func upsert(_ account: Account) {
        if account.isDerivedLightning {
            return
        } else if account.isEphemeral {
            if !ephAccounts.contains(where: { $0.id == account.id }) {
                ephAccounts += [account]
            }
            return
        }
        var currentList = accounts
        if let index = currentList.firstIndex(where: { $0.id == account.id }) {
            currentList.replaceSubrange(index...index, with: [account])
        } else {
            currentList.append(account)
        }
        accounts = currentList
    }

    public func remove(_ account: Account) async {
        let wm = WalletsRepository.shared.getOrAdd(for: account)
        try? await wm.unregisterLightning()
        try? await wm.removeLightningShortcut()
        if !account.isDerivedLightning {
            // full wallet deletion
            try? await wm.removeLightning()
            account.removePinKeychainData()
            account.removeBioKeychainData()
        }
        accounts.removeAll(where: { $0.id == account.id})
    }

    public func removeAll() async {
        for account in accounts {
            await remove(account)
        }
        reset()
    }

    public func reset() {
        accounts = []
        try? storage.removeAll()
    }

    public func getUniqueAccountName(testnet: Bool, watchonly: Bool? = false) -> String {
        let baseName = "\(testnet ? "Testnet ": "")\(watchonly ?? false ? "Watchonly ": "")Wallet"
        for num in 0...999 {
            let name = num == 0 ? baseName : "\(baseName) #\(num + 1)"
            if (AccountsRepository.shared.swAccounts.filter { $0.name.lowercased().hasPrefix(name.lowercased()) }.count) > 0 {
            } else {
                return name
            }
        }
        return baseName
    }
}
