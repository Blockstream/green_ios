import Foundation
import gdk

public enum MigrationFlag: String {
    case appDataVersion = "app_data_version"
    case firstInitialization = "FirstInitialization"
}
public class MigratorManager {

    public static let shared = MigratorManager()
    private var appDataVersion: Int {
        get {
            let version = UserDefaults.standard.integer(forKey: MigrationFlag.appDataVersion.rawValue)
            if version == 0 {
                return 2
            }
            return version
        }
        set {
            UserDefaults.standard.set(newValue, forKey: MigrationFlag.appDataVersion.rawValue)
        }
    }
    public var firstInitialization: Bool {
        get { !UserDefaults.standard.bool(forKey: MigrationFlag.firstInitialization.rawValue) }
        set { UserDefaults.standard.set(newValue, forKey: MigrationFlag.firstInitialization.rawValue) }
    }

    public func migrate() async {
        if firstInitialization {
            // first installation or app upgrade from app version < v3.5.5
            await clean()
            migrateWallets()
            firstInitialization = true
            return
        }
        if appDataVersion < 1 {
            // upgrade from app < v4.0.0
            migrateDatadir()
        }
        if appDataVersion < 2 {
            // upgrade from app < v4.0.25
            updateKeychainPolicy()
        }
        appDataVersion = 2
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

    private func clean() async {
        for network in ["mainnet", "testnet", "liquid"] {
            if !UserDefaults.standard.bool(forKey: network + "FirstInitialization") {
                _ = AuthenticationTypeHandler.removeAuth(method: .AuthKeyBiometric, forNetwork: network)
                _ = AuthenticationTypeHandler.removeAuth(method: .AuthKeyPIN, forNetwork: network)
                UserDefaults.standard.set(true, forKey: network + "FirstInitialization")
            }
        }
        await AccountsRepository.shared.removeAll()
    }

    func updateKeychainPolicy() { // from  "4.0.25"
        let keychainStorage = AccountsRepository.shared.storage
        var query = keychainStorage.query.merging(
            [kSecMatchLimit as String: kSecMatchLimitOne, kSecReturnData as String: kCFBooleanTrue ?? true],
            uniquingKeysWith: {_, new in new})
        query.removeValue(forKey: kSecAttrAccessGroup as String)
        var retrivedData: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &retrivedData)
        guard status == errSecSuccess, let data = retrivedData as? Data else {
            return
        }
        try? keychainStorage.write(data)
    }
}
