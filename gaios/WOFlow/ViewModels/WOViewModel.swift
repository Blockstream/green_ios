import Foundation
import core
import UIKit

import greenaddress

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
    
    init(wallet: Wallet) {
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

    func loginMultisig(password: String?) async throws {
        guard let username = wallet.username,
              let password = !password.isNilOrEmpty ? password : wallet.password else {
            throw GaError.GenericError("Invalid credentials")
        }
        AnalyticsManager.shared.loginWalletStart()
        let wm = WalletsRepository.shared.getOrAdd(for: wallet)
        let credentials = Credentials.watchonlyMultisig(username: username, password: password)
        let res = try await wm.loginWatchonly(credentials: credentials)
        wallet.xpubHashId = res?.xpubHashId
        wallet.walletHashId = res?.walletHashId
        WalletsStorage.shared.current = wallet
        AnalyticsManager.shared.loginWalletEnd(account: wallet, loginType: .watchOnly)
    }

    func setupSinglesig(credentials: Credentials) async throws {
        try AuthenticationTypeHandler.setCredentials(method: .AuthKeyWoCredentials, credentials: credentials, for: wallet.keychain)
    }

    func loginSinglesig() async throws {
        AnalyticsManager.shared.loginWalletStart()
        let wm = WalletsRepository.shared.getOrAdd(for: wallet)
        if AuthenticationTypeHandler.findAuth(method: .AuthKeyWoCredentials, forNetwork: wallet.keychain) {
            let credentials = try AuthenticationTypeHandler.getCredentials(method: .AuthKeyWoCredentials, for: wallet.keychain)
            let res = try await wm.loginWatchonly(credentials: credentials)
            wallet.xpubHashId = res?.xpubHashId
            wallet.walletHashId = res?.walletHashId
        } else if AuthenticationTypeHandler.findAuth(method: .AuthKeyWoBioCredentials, forNetwork: wallet.keychain) {
            let credentials = try AuthenticationTypeHandler.getCredentials(method: .AuthKeyWoBioCredentials, for: wallet.keychain)
            let res = try await wm.loginWatchonly(credentials: credentials)
            wallet.xpubHashId = res?.xpubHashId
            wallet.walletHashId = res?.walletHashId
        } else {
            let session = wm.prominentSession!
            let enableBio = AuthenticationTypeHandler.findAuth(method: .AuthKeyBiometric, forNetwork: wallet.keychain)
            let method: AuthenticationTypeHandler.AuthType = enableBio ? .AuthKeyBiometric : .AuthKeyPIN
            let data = try AuthenticationTypeHandler.getPinData(method: method, for: wallet.keychain)
            try await session.connect()
            let decrypt = DecryptWithPinParams(pin: data.plaintextBiometric ?? "", pinData: data)
            let credentials = try await session.decryptWithPin(decrypt)
            let res = try await wm.loginWatchonly(credentials: credentials)
            wallet.xpubHashId = res?.xpubHashId
            wallet.walletHashId = res?.walletHashId
        }
        WalletsStorage.shared.current = wallet
        AnalyticsManager.shared.loginWalletEnd(account: wallet, loginType: .watchOnly)
    }
}
