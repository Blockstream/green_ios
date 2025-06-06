import Foundation
import gdk

public enum MigrationFlag: String {
    case appDataVersion = "app_data_version"
    case firstInitialization = "FirstInitialization"
}
public class MigratorManager {

    public static let shared = MigratorManager()
    let lastMigration = 4
    private var appDataVersion: Int {
        get {
            UserDefaults.standard.integer(forKey: MigrationFlag.appDataVersion.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: MigrationFlag.appDataVersion.rawValue)
        }
    }
    private var firstInitialization: Bool {
        get { !UserDefaults.standard.bool(forKey: MigrationFlag.firstInitialization.rawValue) }
        set { UserDefaults.standard.set(newValue, forKey: MigrationFlag.firstInitialization.rawValue) }
    }

    public func migrate() {
        logger.info("appDataVersion \(self.appDataVersion, privacy: .public)")
        if firstInitialization {
            // first installation or app upgrade from app version < v3.5.5
            if AccountsRepository.shared.accounts.isEmpty {
                migrateWallets()
            }
            firstInitialization = true
        }
        if appDataVersion == 0 {
            // upgrade from app < v4.0.0
            migrateDatadir()
        }
        if appDataVersion <= 1 {
            // upgrade from app < v4.0.25
            try? updateKeychainAccessGroup()
        }
        // upgrade from app < v4.1.7
        if appDataVersion < 3 {
            updateBiometricPolicy()
        }
        if appDataVersion < 4 {
            // upgrade from app < v4.1.7
            try? updateKeychainAccessible()
        }
        appDataVersion = lastMigration
    }

    // only for tests
    private func logs() {
        let keychainStoragev0 = KeychainStorage(account: AccountsRepository.attrAccount, service: AccountsRepository.attrServicev0)
        let query = [
            // without kSecAttrAccessible
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainStoragev0.attrAccount,
            kSecAttrService as String: keychainStoragev0.attrService,
            kSecAttrAccessGroup as String: Bundle.main.appGroup] as [String: Any]
        let data0 = try? keychainStoragev0.read(query)
        let txt0 = String(decoding: data0 ?? Data(), as: UTF8.self)
        logger.info("keychainStoragev0 \(txt0, privacy: .public)")
        let keychainStoragev1 = KeychainStorage(account: AccountsRepository.attrAccount, service: AccountsRepository.attrServicev1)
        let data1 = try? keychainStoragev1.read()
        let txt1 = String(decoding: data1 ?? Data(), as: UTF8.self)
        logger.info("keychainStoragev1 \(txt1, privacy: .public)")
        do {
            let accountsCached = try JSONDecoder().decode([Account].self, from: data1 ?? Data())
            logger.info("accountsCached \(accountsCached.count, privacy: .public)")
        } catch {
            logger.info("accountsCached error \(error.localizedDescription, privacy: .public)")
        }
        if let path = GdkInit.defaults().datadir {
            if let directoryContents = try? FileManager.default.contentsOfDirectory(atPath: path) {
                logger.info("gdk path \(path, privacy: .public)")
                for url in directoryContents {
                    logger.info("\(url, privacy: .public)")
                }
            }
        }
        for network in ["mainnet", "testnet", "liquid"] {
            if AuthenticationTypeHandler.findAuth(method: .AuthKeyPIN, forNetwork: network) {
                logger.info("legacy pin account \(network, privacy: .public)")
            }
            if AuthenticationTypeHandler.findAuth(method: .AuthKeyBiometric, forNetwork: network) {
                logger.info("legacy bio account \(network, privacy: .public)")
            }
        }
        
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
            let txt = String(decoding: data, as: UTF8.self)
            logger.info("MigrateManager: \(txt, privacy: .public)")
            try AccountsRepository.shared.storage.write(data)
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
            let txt = String(decoding: data, as: UTF8.self)
            logger.info("MigrateManager: \(txt, privacy: .public)")
            try AccountsRepository.shared.storage.write(data)
        }
        AccountsRepository.shared.cleanCache()
    }

    func updateBiometricPolicy() { // from  "4.1.7"
        logger.info("MigrateManager: updateBiometricPolicy")
        for account in AccountsRepository.shared.accounts where AuthenticationTypeHandler.findAuth(method: .AuthKeyBiometric, forNetwork: account.keychain) {
            _ = try? AuthenticationTypeHandler.getAuthKeyBiometricPrivateKey(network: account.keychain)
        }
    }
    // only for tests
    public func removeAll() {
        let keychainStoragev0 = KeychainStorage(account: AccountsRepository.attrAccount, service: AccountsRepository.attrServicev0)
        var query = [
            // without kSecAttrAccessible & kSecAttrAccessGroup
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainStoragev0.attrAccount,
            kSecAttrService as String: keychainStoragev0.attrService] as [String: Any]
        try? keychainStoragev0.removeAll(query)
        query[kSecAttrAccessGroup as String] = Bundle.main.appGroup
        try? keychainStoragev0.removeAll(query)
        let keychainStoragev1 = AccountsRepository.shared.storage
        try? keychainStoragev1.removeAll()
        AccountsRepository.shared.cleanCache()
    }
}
