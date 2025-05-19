import Foundation
import UIKit
import gdk
import hw

public struct Account: Codable, Equatable {

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case isJade
        case isLedger
        case username
        case password
        case keychain
        case chain = "network"
        case network = "gdknetwork"
        case isSingleSig
        case walletHashId = "wallet_hash_id"
        case askEphemeral = "ask_ephemeral"
        case xpubHashId = "xpub_hash_id"
        case hidden
        case uuid
        case lightningWalletHashId = "lightning_wallet_hash_id"
        case watchonly
        case efusemac
        case boardType
    }

    public var name: String
    public let id: String
    public let isJade: Bool
    public let isLedger: Bool
    public let username: String?
    public var password: String?
    public let keychain: String
    private var network: String? // use NetworkType for retro-compatibility
    private var chain: String? // legacy field
    private var isSingleSig: Bool? // legacy field
    public var walletHashId: String?
    public var xpubHashId: String?
    public var hidden: Bool? = false
    public var uuid: UUID?
    public var isEphemeral: Bool = false
    public var askEphemeral: Bool?
    public var ephemeralId: Int?
    public var isDerivedLightning: Bool = false
    public var lightningWalletHashId: String?
    private var watchonly: Bool?
    public var isWatchonly: Bool { watchonly ?? false || username != nil }
    public var efusemac: String?
    public var boardType: JadeBoardType?

    public init(id: String? = nil, name: String, network: NetworkSecurityCase, isJade: Bool = false, isLedger: Bool = false, isSingleSig: Bool? = nil, isEphemeral: Bool = false, askEphemeral: Bool = false, xpubHashId: String? = nil, walletHashId: String? = nil, lightningWalletHashId: String? = nil, uuid: UUID? = nil, hidden: Bool = false, isDerivedLightning: Bool = false, password: String? = nil, watchonly: Bool? = nil) {
        // Software / Hardware wallet account
        self.id = id ?? UUID().uuidString
        self.name = name
        self.network = network.network
        self.isJade = isJade
        self.isLedger = isLedger
        self.username = nil
        self.password = nil
        self.keychain = self.id
        self.isSingleSig = isSingleSig
        self.isEphemeral = isEphemeral
        self.askEphemeral = askEphemeral
        self.xpubHashId = xpubHashId
        self.walletHashId = walletHashId
        self.lightningWalletHashId = lightningWalletHashId
        self.uuid = uuid
        self.hidden = hidden
        self.isDerivedLightning = isDerivedLightning
        self.password = password
        self.watchonly = watchonly
        if isEphemeral {
            let ephAccounts = AccountsRepository.shared.ephAccounts
            if ephAccounts.count == 0 {
                self.ephemeralId = 1
            } else {
                if let last = ephAccounts.sorted(by: { ($0.ephemeralId ?? 0) > ($1.ephemeralId ?? 0) }).first, let id = last.ephemeralId {
                    self.ephemeralId = id + 1
                }
            }
        }
    }

    public init(name: String, network: NetworkSecurityCase, username: String, password: String? = nil) {
        // Watchonly account
        id = UUID().uuidString
        self.name = name
        self.network = network.network
        self.isJade = false
        self.isLedger = false
        self.username = username
        self.password = password
        self.keychain = id
        self.watchonly = true
    }

    public init(name: String, network: NetworkSecurityCase, keychain: String) {
        // Migrated account
        id = UUID().uuidString
        self.name = name
        self.network = network.network
        self.keychain = keychain
        self.isJade = false
        self.isLedger = false
        self.username = nil
        self.password = nil
    }

    public var isHW: Bool { isJade || isLedger }

    public var hasManualPin: Bool {
        get {
            return AuthenticationTypeHandler.findAuth(method: .AuthKeyPIN, forNetwork: keychain)
        }
    }

    public var hasBioPin: Bool {
        get {
            AuthenticationTypeHandler.findAuth(method: .AuthKeyBiometric, forNetwork: keychain)
        }
    }

    public var hasWoBioCredentials: Bool {
        get {
            AuthenticationTypeHandler.findAuth(method: .AuthKeyWoBioCredentials, forNetwork: keychain)
        }
    }
    
    public var hasWoCredentials: Bool {
        get {
            AuthenticationTypeHandler.findAuth(method: .AuthKeyWoCredentials, forNetwork: keychain)
        }
    }

    public var hasPin: Bool {
        get {
            return hasManualPin || hasBioPin
        }
    }

    public var icon: UIImage {
        get {
            switch network {
            case "mainnet":
                return UIImage(named: "ntw_btc")!
            case "liquid":
                return UIImage(named: "ntw_liquid")!
            case "testnet-liquid":
                return UIImage(named: "ntw_testnet_liquid")!
            default:
                return UIImage(named: "ntw_testnet")!
            }
        }
    }

    public var attempts: Int {
        get {
            return UserDefaults.standard.integer(forKey: keychain + "_pin_attempts")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: keychain + "_pin_attempts")
        }
    }

    public func removeBioKeychainData() {
        _ = AuthenticationTypeHandler.removeAuth(method: .AuthKeyBiometric, for: keychain)
        try? AuthenticationTypeHandler.removePrivateKey(forNetwork: keychain)
        UserDefaults.standard.set(nil, forKey: "AuthKeyBiometricPrivateKey" + keychain)
    }

    public func removePinKeychainData() {
        _ = AuthenticationTypeHandler.removeAuth(method: .AuthKeyPIN, for: keychain)
    }
/*
    public func removeLightningShortcut() {
        _ = AuthenticationTypeHandler.removeAuth(method: .AuthKeyLightning, forNetwork: keychain)
    }

    public func removeLightningCredentials() {
        if let walletHashId = walletHashId {
            LightningRepository.shared.remove(for: walletHashId)
        }
    }
*/
    public func addBiometrics(session: SessionManager, credentials: Credentials) async throws {
        let password = String.random(length: 14)
        let params = EncryptWithPinParams(pin: password, credentials: credentials)
        let encrypted = try await session.encryptWithPin(params)
        try AuthenticationTypeHandler.setPinData(method: .AuthKeyBiometric, pinData: encrypted.pinData, extraData: password, for: keychain)
    }

    public func addPin(session: SessionManager, pin: String, credentials: Credentials) async throws {
        let params = EncryptWithPinParams(pin: pin, credentials: Credentials(mnemonic: credentials.mnemonic, password: credentials.password))
        let encrypted = try await session.encryptWithPin(params)
        try AuthenticationTypeHandler.setPinData(method: .AuthKeyPIN, pinData: encrypted.pinData, extraData: nil, for: keychain)
    }

    public var gdkNetwork: GdkNetwork { networkType.gdkNetwork }
    public var networkType: NetworkSecurityCase {
        get {
            if let network = network {
                return NetworkSecurityCase(rawValue: network) ?? .bitcoinSS
            }
            let chain = self.chain ?? "mainnet"
            let name =  isSingleSig ?? false ? "electrum-" + chain : chain
            return NetworkSecurityCase(rawValue: name) ?? .bitcoinSS
        }
        set {
            self.network = newValue.rawValue
        }
    }

    public func getDerivedLightningAccount() -> Account? {
        let account = Account(
                id: "\(id)-lightning-shortcut",
                name: name,
                network: .bitcoinSS,
                isJade: isJade,
                xpubHashId: xpubHashId,
                walletHashId: walletHashId,
                lightningWalletHashId: lightningWalletHashId,
                isDerivedLightning: true,
                password: password,
                watchonly: false
        )
        if AuthenticationTypeHandler.findAuth(method: .AuthKeyLightning, forNetwork: account.keychain) {
            return account
        }
        return nil
    }

    public var walletIdentifier: WalletIdentifier? {
        return WalletIdentifier(walletHashId: walletHashId ?? "", xpubHashId: xpubHashId ?? "")
    }
}
