import Foundation
import gdk

public class WalletsStorage {

    static let attrAccount = "AccountsManager_Account"
    static let attrServicev0 = "AccountsManager_Service"
    static let attrServicev1 = "AccountsManager_Service_v1"
    private static let addWalletKey = "ADD_WALLET"

    public static let shared = WalletsStorage()
    let storage = KeychainStorage(account: WalletsStorage.attrAccount, service: WalletsStorage.attrServicev1)

    // List of saved wallets with cache
    private var walletsCached: [Wallet]?
    public var wallets: [Wallet] {
        get {
            if let cached = walletsCached {
                return cached
            }
            do {
                let data = try? storage.read()
                walletsCached = try JSONDecoder().decode([Wallet].self, from: data ?? Data())
            } catch {
                logger.error("WalletsStorage error \(error.localizedDescription, privacy: .public)")
            }
            return walletsCached ?? []
        }
        set {
            try? storage.write(newValue.encoded())
            walletsCached = newValue
        }
    }

    // Current wallet
    private var currentId = ""
    public var current: Wallet? {
        get {
            get(for: currentId)
        }
        set {
            if newValue?.xpubHashId == nil || newValue?.walletHashId == nil {
                logger.error("No xpub or wallet hash id")
            }
            currentId = newValue?.id ?? ""
            if let wallet = newValue {
                upsert(wallet)
            }
        }
    }

    // Filtered wallet list of software wallets
    public var sws: [Wallet] { wallets.filter { !$0.isHW } }

    // Filtered wallet list of software ephemeral wallets
    public var ephs: [Wallet] = [Wallet]()

    // Filtered wallet list of hardware wallets
    public var hws: [Wallet] { wallets.filter { $0.isHW } }
    public var hwsVisible: [Wallet] { hws.filter { !($0.hidden ?? true) } }

    public func cleanCache() {
        walletsCached = nil
    }

    public func get(for id: String) -> Wallet? {
        ephs.filter({ $0.id == id }).first ??
        wallets.filter({ $0.id == id }).first
    }

    public func find(xpubHashId: String) -> [Wallet]? {
        ephs.filter({ $0.xpubHashId == xpubHashId }) +
        wallets.filter({ $0.xpubHashId == xpubHashId })
    }

    public func upsert(_ wallet: Wallet) {
        if wallet.isEphemeral {
            if !ephs.contains(where: { $0.id == wallet.id }) {
                ephs += [wallet]
            }
            return
        }
        var currentList = wallets
        if let index = currentList.firstIndex(where: { $0.id == wallet.id }) {
            currentList.replaceSubrange(index...index, with: [wallet])
        } else {
            currentList.append(wallet)
        }
        wallets = currentList
    }

    public func remove(_ wallet: Wallet) async {
        wallet.removeAuthentication(.AuthKeyPIN)
        wallet.removeAuthentication(.AuthKeyBiometric)
        wallet.removeAuthentication(.AuthKeyWoBioCredentials)
        wallet.removeAuthentication(.AuthKeyWoCredentials)
        wallet.removeAuthentication(.AuthKeyBoltz)
        wallet.removeAuthentication(.AuthKeyLightning)
        ephs.removeAll(where: { $0.id == wallet.id})
        wallets.removeAll(where: { $0.id == wallet.id})
    }

    public func removeAll() async {
        for wallet in wallets {
            await remove(wallet)
        }
        wallets = []
        try? storage.removeAll()
    }

    public func getUniqueAccountName(testnet: Bool, watchonly: Bool? = false) -> String {
        let baseName = "\(testnet ? "Testnet ": "")\(watchonly ?? false ? "Watchonly ": "")Wallet"
        for num in 0...999 {
            let name = num == 0 ? baseName : "\(baseName) #\(num + 1)"
            if (WalletsStorage.shared.sws.filter { $0.name.lowercased().hasPrefix(name.lowercased()) }.count) > 0 {
            } else {
                return name
            }
        }
        return baseName
    }

    public func injectWalletFromEnvironment() {
        guard let base64Wallet = UserDefaults.standard.string(forKey: Self.addWalletKey),
              !base64Wallet.isEmpty,
              let data = Data(base64Encoded: base64Wallet),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let walletJson = json["wallet"] as? [String: Any],
              let network = walletJson["network"] as? String else { return }
        let walletName = walletJson["name"] as? String ?? network
        let networkCase = NetworkSecurityCase(rawValue: network) ?? .bitcoinSS
        let wallet = Wallet(name: walletName, network: networkCase)
        upsert(wallet)
        if let loginCredentials = json["login_credentials"] as? [AnyHashable: Any],
           let credentials = Credentials.from(loginCredentials) as? Credentials,
           let pinData = credentials.pinData {
            try? AuthenticationTypeHandler.setPinData(
                method: .AuthKeyPIN,
                pinData: pinData,
                extraData: nil,
                for: wallet.keychain
            )
        }

        UserDefaults.standard.removeObject(forKey: Self.addWalletKey)
    }
}
