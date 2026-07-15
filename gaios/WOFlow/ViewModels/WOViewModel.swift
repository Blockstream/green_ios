import Foundation
import core
import UIKit

import greenaddress

enum WOImportType: CaseIterable {
    case slip132
    case descriptor
}

struct WOImportInput {
    let type: WOImportType
    let keys: [String]
    let credentials: Credentials
    let network: NetworkId
}

enum WOImportValidationError: LocalizedError {
    case invalidKey(String)
    case invalidDescriptor(String)
    var errorDescription: String? {
        switch self {
        case .invalidKey(let key):
            return "Invalid key \(key)"
        case .invalidDescriptor(let desc):
            return "Invalid descriptor \(desc)"
        }
    }
}

struct WOCellModel {
    let img: UIImage
    let title: String
    let hint: String
}

class WOViewModel {

    var wallet: Wallet

    let types: [WOCellModel] = [
        WOCellModel(img: UIImage(named: "ic_key_ss")!,
                    title: "id_singlesig".localized,
                    hint: "id_enter_your_xpub_to_add_a".localized),
        WOCellModel(img: UIImage(named: "ic_key_ms")!,
                    title: "id_multisig_shield".localized,
                    hint: "id_log_in_to_your_multisig_shield".localized)
    ]

    internal init(wallet: Wallet) {
        self.wallet = wallet
    }

    static func newAccountMultisig(for gdkNetwork: GdkNetwork, username: String, password: String, remember: Bool) -> Wallet {
        let name = WalletsStorage.shared.getUniqueAccountName(
            testnet: !gdkNetwork.mainnet,
            watchonly: true)
        let network = NetworkId(rawValue: gdkNetwork.network) ?? .electrumMainnet
        return Wallet(name: name, network: network, username: username, password: remember ? password : nil)
    }

    static func newAccountSinglesig(for gdkNetwork: GdkNetwork) -> Wallet {
        let name = WalletsStorage.shared.getUniqueAccountName(
            testnet: !gdkNetwork.mainnet,
            watchonly: true)
        let network = NetworkId(rawValue: gdkNetwork.network) ?? .electrumMainnet
        return Wallet(name: name, network: network, username: "")
    }

    static func validateImport(text: String) throws -> WOImportInput {
        let isListOfPubKeys = ["xpub", "ypub", "zpub", "tpub", "upub", "vpub"].contains(text.prefix(4).lowercased())
        let type: WOImportType = isListOfPubKeys ? .slip132 : .descriptor
        let keys = text
            .split(whereSeparator: { $0 == "\n" || $0 == " " || (isListOfPubKeys && $0 == ",") })
            .map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
        let allNetworks: [NetworkId] = [.electrumMainnet, .electrumLiquid, .electrumTestnet, .electrumTestnetLiquid]
        let btcNetworks: [NetworkId] = [.electrumMainnet, .electrumTestnet]
        if isListOfPubKeys {
            for key in keys {
                if btcNetworks.filter({ Wally.isPubKey(key, for: $0) }).isEmpty {
                    throw WOImportValidationError.invalidKey(key)
                }
            }
        } else {
            for desc in keys {
                if allNetworks.filter({ Wally.isDescriptor(desc, for: $0) }).isEmpty {
                    throw WOImportValidationError.invalidDescriptor(desc)
                }
            }
        }
        let credentials = Credentials(
            coreDescriptors: isListOfPubKeys ? nil : keys,
            slip132ExtendedPubkeys: isListOfPubKeys ? keys : nil
        )
        let network = isListOfPubKeys
            ? keys.compactMap { Wally.getNetwork(xpub: $0) }.first
            : keys.compactMap { Wally.getNetwork(descriptor: $0) }.first
        return WOImportInput(
            type: type,
            keys: keys,
            credentials: credentials,
            network: network ?? .electrumMainnet
        )
    }

    func importSinglesig(credentials: Credentials, network: NetworkId) async throws {
        try await loginWatchonly(credentials: credentials)
        try await setupSinglesig(credentials: credentials)
    }

    func loginMultisig(password: String?) async throws {
        guard let username = wallet.username,
              let password = !password.isNilOrEmpty ? password : wallet.password else {
            throw GaError.GenericError("Invalid credentials")
        }
        let credentials = Credentials.watchonlyMultisig(username: username, password: password)
        try await loginWatchonly(credentials: credentials)
    }

    func loginWatchonly(credentials: Credentials) async throws {
        AnalyticsManager.shared.loginWalletStart()
        let wm = WalletsRepository.shared.getOrAdd(for: wallet)
        let res = try await wm.login(
            credentials: credentials,
            lightningCredentials: nil,
            boltzCredentials: nil,
            device: nil,
            fullRestore: false,
            creation: false,
            parentXpub: wallet.xpubHashId
        )
        wallet.applyLoginResult(res, credentials: credentials)
        WalletsStorage.shared.current = wallet
        AnalyticsManager.shared.loginWalletEnd(account: wallet, loginType: .watchOnly)
    }

    func setupSinglesig(credentials: Credentials) async throws {
        try AuthenticationTypeHandler.setCredentials(method: .AuthKeyWoCredentials, credentials: credentials, for: wallet.keychain)
    }

    func getCredentials() async throws -> Credentials {
        let wm = WalletsRepository.shared.getOrAdd(for: wallet)
        if AuthenticationTypeHandler.findAuth(method: .AuthKeyWoCredentials, forNetwork: wallet.keychain) {
            return try AuthenticationTypeHandler.getCredentials(method: .AuthKeyWoCredentials, for: wallet.keychain)
        } else if AuthenticationTypeHandler.findAuth(method: .AuthKeyWoBioCredentials, forNetwork: wallet.keychain) {
            return try AuthenticationTypeHandler.getCredentials(method: .AuthKeyWoBioCredentials, for: wallet.keychain)
        } else {
            let session = wm.prominentSession
            let enableBio = AuthenticationTypeHandler.findAuth(method: .AuthKeyBiometric, forNetwork: wallet.keychain)
            AnalyticsManager.shared.loginWalletStart()
            let method: AuthenticationTypeHandler.AuthType = enableBio ? .AuthKeyBiometric : .AuthKeyPIN
            let data = try AuthenticationTypeHandler.getPinData(method: method, for: wallet.keychain)
            try await session.connect()
            let decrypt = DecryptWithPinParams(pin: data.plaintextBiometric ?? "", pinData: data)
            return try await session.decryptWithPin(decrypt)
        }
    }

    func loginSinglesig() async throws {
        let credentials = try await getCredentials()
        try await loginWatchonly(credentials: credentials)
    }

    static func parseGenericJson(_ content: [String: Any]) -> [String]? {
        // Colcard format
        return content.compactMap { $0.value as? [String: Any] }
            .compactMap { bip -> String? in
                let name = bip?["name"] as? String
                if let name = name, let type = AccountType(rawValue: name), AccountType.allCases.contains(type) {
                    let pub = bip?["_pub"] as? String
                    let xpub = bip?["xpub"] as? String
                    return pub ?? xpub ?? nil
                }
                return nil
            }
    }

    static func parseElectrumJson(_ content: [String: Any]) -> [String]? {
        // Electrum format
        return content.filter { $0.key == "keystore" }
            .compactMap { $0.value as? [String: Any] }
            .compactMap { $0["xpub"] as? String }
    }

}
