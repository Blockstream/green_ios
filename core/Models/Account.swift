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
    private var watchonly: Bool?
    public var isWatchonly: Bool { watchonly ?? false || username != nil }
    public var efusemac: String?
    public var boardType: JadeBoardType?

    public init(id: String? = nil, name: String, network: NetworkSecurityCase, isJade: Bool = false, isLedger: Bool = false, isSingleSig: Bool? = nil, isEphemeral: Bool = false, askEphemeral: Bool = false, xpubHashId: String? = nil, walletHashId: String? = nil, uuid: UUID? = nil, hidden: Bool = false, username: String? = nil, password: String? = nil, watchonly: Bool? = nil, keychain: String? = nil) {
        // Software / Hardware wallet account
        self.id = id ?? UUID().uuidString
        self.name = name
        self.network = network.network
        self.isJade = isJade
        self.isLedger = isLedger
        self.keychain = keychain ?? self.id
        self.isSingleSig = isSingleSig
        self.isEphemeral = isEphemeral
        self.askEphemeral = askEphemeral
        self.xpubHashId = xpubHashId
        self.walletHashId = walletHashId
        self.uuid = uuid
        self.hidden = hidden
        self.username = username
        self.password = password
        self.watchonly = watchonly
    }

    public var ephemeralId: Int? {
        if !isEphemeral {
            return nil
        }
        return AccountsRepository.shared.ephAccounts
            .filter({ $0.keychain == keychain })
            .firstIndex(of: self) ?? 0 + 1
    }

    public var isHW: Bool { isJade || isLedger }
    public func hasAuthentication(_ method: AuthenticationTypeHandler.AuthType) -> Bool {
        AuthenticationTypeHandler.findAuth(method: method, forNetwork: keychain)
    }
    public var hasManualPin: Bool { hasAuthentication(.AuthKeyPIN) }
    public var hasBioPin: Bool { hasAuthentication(.AuthKeyBiometric) }
    public var hasWoCredentials: Bool { hasAuthentication(.AuthKeyWoCredentials) }
    public var hasWoBioCredentials: Bool { hasAuthentication(.AuthKeyWoBioCredentials) }
    public var hasLightningKey: Bool { hasAuthentication(.AuthKeyLightning) }
    public var hasPin: Bool { hasManualPin || hasBioPin }

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

    public func removeAuthentication(_ method: AuthenticationTypeHandler.AuthType) {
        _ = AuthenticationTypeHandler.removeAuth(method: method, for: keychain)
        if method == .AuthKeyBiometric {
            AuthenticationTypeHandler.removePrivateKey(forNetwork: keychain)
            UserDefaults.standard.set(nil, forKey: "AuthKeyBiometricPrivateKey" + keychain)
        }
    }
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

    public var walletIdentifier: WalletIdentifier? {
        return WalletIdentifier(walletHashId: walletHashId ?? "", xpubHashId: xpubHashId ?? "")
    }
    public var keychainLightning: String {
        return "\(keychain)-lightning-shortcut"
    }
}
