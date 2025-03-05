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
        if appDataVersion == 1 {
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

    private func migrateDatadir() { // from "4.0.0"
        // move cache dir to the app support
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
        var accounts = [Account]()
        for network in ["mainnet", "testnet", "liquid"] {
            let bioData = AuthenticationTypeHandler.findAuth(method: .AuthKeyBiometric, forNetwork: network)
            let pinData = AuthenticationTypeHandler.findAuth(method: .AuthKeyPIN, forNetwork: network)
            if pinData || bioData {
                let networkType = NetworkSecurityCase(rawValue: network) ?? .bitcoinMS
                var account = Account(name: network.firstCapitalized, network: networkType, keychain: network)
                account.attempts = UserDefaults.standard.integer(forKey: network + "_pin_attempts")
                accounts.append(account)
            }
        }
        AccountsRepository.shared.accounts = accounts
    }

    func updateKeychainAccessGroup() throws { // from  "4.0.25"
        let keychainStoragev0 = KeychainStorage(account: AccountsRepository.attrAccount, service: AccountsRepository.attrServicev0)
        let query = [
            // without kSecAttrAccessible & kSecAttrAccessGroup
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainStoragev0.attrAccount,
            kSecAttrService as String: keychainStoragev0.attrService] as [String: Any]
        if let data = try keychainStoragev0.read(query) {
            try AccountsRepository.shared.storage.write(data)
        }
        AccountsRepository.shared.cleanCache()
    }

    func updateKeychainAccessible() throws { // from "4.1.0"
        let keychainStoragev0 = KeychainStorage(account: AccountsRepository.attrAccount, service: AccountsRepository.attrServicev0)
        let query = [
            // without kSecAttrAccessible
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainStoragev0.attrAccount,
            kSecAttrService as String: keychainStoragev0.attrService,
            kSecAttrAccessGroup as String: Bundle.main.appGroup] as [String: Any]
        if let data = try keychainStoragev0.read(query) {
            try AccountsRepository.shared.storage.write(data)
        }
        AccountsRepository.shared.cleanCache()
    }

    func updateBiometricPolicy() { // from  "4.1.7"
        for account in AccountsRepository.shared.accounts where AuthenticationTypeHandler.findAuth(method: .AuthKeyBiometric, forNetwork: account.keychain) {
            _ = try? AuthenticationTypeHandler.getAuthKeyBiometricPrivateKey(network: account.keychain)
        }
    }
}
