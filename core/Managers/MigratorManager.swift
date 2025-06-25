import Foundation
import gdk

public class MigratorManager {

    public static let shared = MigratorManager()

    public func migrate() {
        // check existing keychain storage
        if !nilKeychainStorage() {
            return
        }
        try? updateKeychainAccessible()
        if !nilKeychainStorage() {
            return
        }
        try? updateKeychainAccessGroup()
        if !nilKeychainStorage() {
            return
        }
        migrateWallets()
        migrateDatadir()
    }

    var keychainStoragev0 = KeychainStorage(account: AccountsRepository.attrAccount, service: AccountsRepository.attrServicev0)
    var keychainStoragev1 = KeychainStorage(account: AccountsRepository.attrAccount, service: AccountsRepository.attrServicev1)

    func nilKeychainStorage() -> Bool {
        let storagev1 = try? keychainStoragev1.read()
        return storagev1 == nil
    }

    private func migrateDatadir() { // from "4.0.0"
        // move cache dir to the app support
        logger.info("MigrateManager: migrateDatadir")
        let params = GdkInit.defaults()
        let url = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
        if let atPath = url?.path, let toPath = params.datadir,
            FileManager.default.fileExists(atPath: atPath) {
            let files = try? FileManager.default.contentsOfDirectory(atPath: atPath)
            files?.forEach { file in
                try? FileManager.default.moveItem(atPath: "\(atPath)/\(file)", toPath: "\(toPath)/\(file)")
            }
        }
    }

    private func migrateWallets() { // from "3.5.5"
        logger.info("MigrateManager: migrateWallets")
        var accounts: [Account]?
        for network in ["mainnet", "testnet", "liquid"] {
            let bioData = AuthenticationTypeHandler.findAuth(method: .AuthKeyBiometric, forNetwork: network)
            let pinData = AuthenticationTypeHandler.findAuth(method: .AuthKeyPIN, forNetwork: network)
            if pinData || bioData {
                let networkType = NetworkSecurityCase(rawValue: network) ?? .bitcoinMS
                var account = Account(name: network.firstCapitalized, network: networkType, keychain: network)
                account.attempts = UserDefaults.standard.integer(forKey: network + "_pin_attempts")
                if accounts == nil {
                    accounts = [account]
                } else {
                    accounts?.append(account)
                }
            }
        }
        if let accounts = accounts {
            logger.info("MigrateManager: \(accounts.debugDescription, privacy: .public)")
            AccountsRepository.shared.accounts = accounts
        }
    }

    func updateKeychainAccessGroup() throws { // from  "4.0.25"
        logger.info("MigrateManager: updateKeychainAccessGroup")
        let keychainStoragev0 = KeychainStorage(account: AccountsRepository.attrAccount, service: AccountsRepository.attrServicev0)
        let query = [
            // without kSecAttrAccessible & kSecAttrAccessGroup
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainStoragev0.attrAccount,
            kSecAttrService as String: keychainStoragev0.attrService] as [String: Any]
        if let data = try keychainStoragev0.read(query) {
            try keychainStoragev1.write(data)
        }
        AccountsRepository.shared.cleanCache()
    }

    func updateKeychainAccessible() throws { // from "4.1.0"
        logger.info("MigrateManager: updateKeychainAccessible")
        let keychainStoragev0 = KeychainStorage(account: AccountsRepository.attrAccount, service: AccountsRepository.attrServicev0)
        let query = [
            // without kSecAttrAccessible
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainStoragev0.attrAccount,
            kSecAttrService as String: keychainStoragev0.attrService,
            kSecAttrAccessGroup as String: Bundle.main.appGroup] as [String: Any]
        if let data = try keychainStoragev0.read(query) {
            try keychainStoragev1.write(data)
        }
        AccountsRepository.shared.cleanCache()
    }

    // only for tests
    public func removeAll() {
        var query = [
            // without kSecAttrAccessible & kSecAttrAccessGroup
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainStoragev0.attrAccount,
            kSecAttrService as String: keychainStoragev0.attrService] as [String: Any]
        try? keychainStoragev0.removeAll(query)
        query[kSecAttrAccessGroup as String] = Bundle.main.appGroup
        try? keychainStoragev0.removeAll(query)
        try? keychainStoragev1.removeAll()
        AccountsRepository.shared.cleanCache()
    }
}
