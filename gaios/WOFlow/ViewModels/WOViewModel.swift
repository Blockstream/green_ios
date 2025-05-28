import Foundation
import core
import UIKit
import gdk
import greenaddress

struct WOCellModel {
    let img: UIImage
    let title: String
    let hint: String
}

class WOViewModel {

    let types: [WOCellModel] = [
        WOCellModel(img: UIImage(named: "ic_key_ss")!,
                    title: "id_singlesig".localized,
                    hint: "id_enter_your_xpub_to_add_a".localized),
        WOCellModel(img: UIImage(named: "ic_key_ms")!,
                    title: "id_multisig_shield".localized,
                    hint: "id_log_in_to_your_multisig_shield".localized)
    ]

    func newAccountMultisig(for gdkNetwork: GdkNetwork, username: String, password: String, remember: Bool ) -> Account {
        let name = AccountsRepository.shared.getUniqueAccountName(
            testnet: !gdkNetwork.mainnet,
            watchonly: true)
        let network = NetworkSecurityCase(rawValue: gdkNetwork.network) ?? .bitcoinSS
        return Account(name: name, network: network, username: username, password: remember ? password : nil)
    }

    func newAccountSinglesig(for gdkNetwork: GdkNetwork) -> Account {
        let name = AccountsRepository.shared.getUniqueAccountName(
            testnet: !gdkNetwork.mainnet,
            watchonly: true)
        let network = NetworkSecurityCase(rawValue: gdkNetwork.network) ?? .bitcoinSS
        return Account(name: name, network: network, username: "")
    }

    func loginMultisig(for account: Account, password: String?) async throws {
        guard let username = account.username,
              let password = !password.isNilOrEmpty ? password : account.password else {
            throw GaError.GenericError("Invalid credentials")
        }
        AnalyticsManager.shared.loginWalletStart()
        let wm = WalletsRepository.shared.getOrAdd(for: account)
        let credentials = Credentials.watchonlyMultisig(username: username, password: password)
        try await wm.loginWatchonly(credentials: credentials)
        AccountsRepository.shared.current = wm.account
        AnalyticsManager.shared.loginWalletEnd(account: wm.account, loginType: .watchOnly)
    }

    func setupSinglesig(for account: Account, credentials: Credentials) async throws {
        try AuthenticationTypeHandler.setCredentials(method: .AuthKeyWoCredentials, credentials: credentials, for: account.keychain)
    }

    func loginSinglesig(for account: Account) async throws {
        AnalyticsManager.shared.loginWalletStart()
        let wm = WalletsRepository.shared.getOrAdd(for: account)
        let existCredentials = AuthenticationTypeHandler.findAuth(method: .AuthKeyWoCredentials, forNetwork: account.keychain)
        if existCredentials {
            let credentials = try AuthenticationTypeHandler.getCredentials(method: .AuthKeyWoCredentials, for: account.keychain)
            try await wm.loginWatchonly(credentials: credentials)
        } else {
            let session = wm.prominentSession!
            let enableBio = AuthenticationTypeHandler.findAuth(method: .AuthKeyBiometric, forNetwork: account.keychain)
            let method: AuthenticationTypeHandler.AuthType = enableBio ? .AuthKeyBiometric : .AuthKeyPIN
            let data = try AuthenticationTypeHandler.getPinData(method: method, for: account.keychain)
            try await session.connect()
            let decrypt = DecryptWithPinParams(pin: data.plaintextBiometric ?? "", pinData: data)
            let credentials = try await session.decryptWithPin(decrypt)
            try await wm.loginWatchonly(credentials: credentials)
        }
        AccountsRepository.shared.current = wm.account
        AnalyticsManager.shared.loginWalletEnd(account: wm.account, loginType: .watchOnly)
    }
}
