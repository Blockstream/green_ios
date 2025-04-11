import Foundation
import LocalAuthentication
import gdk
import core

class LoginViewModel {

    var account: Account
    init(account: Account) {
        self.account = account
    }

    func auth() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let context = LAContext()
            var error: NSError?
            context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
            if error != nil {
                continuation.resume(throwing: AuthenticationTypeHandler.AuthError.CanceledByUser)
            }
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Authentication" ) { success, error in
                if error != nil {
                    continuation.resume(throwing: AuthenticationTypeHandler.AuthError.CanceledByUser)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func decryptCredentials(usingAuth: AuthenticationTypeHandler.AuthType, withPIN: String?) async throws -> Credentials {
        let pinData = try AuthenticationTypeHandler.getPinData(method: usingAuth, for: account.keychain)
        if !pinData.encryptedData.isEmpty {
            // need decrypt with pin server
            let pin = withPIN ?? pinData.plaintextBiometric
            let decryptData = DecryptWithPinParams(pin: pin ?? "", pinData: pinData)
            let session = SessionManager(account.gdkNetwork)
            try await session.connect()
            return try await session.decryptWithPin(decryptData)
        }
        return Credentials(mnemonic: pinData.plaintextBiometric, pinData: pinData)
    }

    func loginWithPin(usingAuth: AuthenticationTypeHandler.AuthType, withPIN: String?, bip39passphrase: String?) async throws {
        AnalyticsManager.shared.loginWalletStart()
        var credentials = try await decryptCredentials(usingAuth: usingAuth, withPIN: withPIN)
        credentials.bip39Passphrase = bip39passphrase
        // to support legacy gdk behaviour
        credentials.password = credentials.password == "" ? nil : credentials.password
        if !bip39passphrase.isNilOrEmpty {
            account = updateEphemeralAccount(from: credentials)
        }
        let wallet = try await loginWithCredentials(credentials: credentials)
        account = wallet.account
        if withPIN != nil {
            account.attempts = 0
        }
        AccountsRepository.shared.current = account
    }

    func loginWithCredentials(credentials: Credentials) async throws -> WalletManager {
        let wm = WalletsRepository.shared.getOrAdd(for: account)
        wm.popupResolver = await PopupResolver()
        wm.hwInterfaceResolver = await HwPopupResolver()
        let lightningMnemonic = try wm.getLightningMnemonic(credentials: credentials)
        let lightningCredentials = Credentials(mnemonic: lightningMnemonic, bip39Passphrase: credentials.bip39Passphrase)
        let walletIdentifier = try wm.prominentSession?.walletIdentifier(credentials: credentials)
        try await wm.login(
            credentials: credentials,
            lightningCredentials: lightningCredentials,
            device: nil,
            masterXpub: nil,
            fullRestore: false,
            parentWalletId: walletIdentifier)
        account = wm.account
        AccountsRepository.shared.current = account
        return wm
    }

    fileprivate func updateEphemeralAccount(from credentials: Credentials) -> Account {
        let networkType = account.networkType.testnet ? NetworkSecurityCase.testnetSS : NetworkSecurityCase.bitcoinSS
        let session = SessionManager(networkType.gdkNetwork)
        let walletId = try? session.walletIdentifier(credentials: credentials)
        if !credentials.bip39Passphrase.isNilOrEmpty {
            if let account = AccountsRepository.shared.ephAccounts.first(where: { $0.xpubHashId == walletId?.xpubHashId }) {
                return account
            }
        }
        var newAccount = Account(name: account.name, network: networkType, keychain: account.keychain)
        newAccount.isEphemeral = true
        newAccount.attempts = account.attempts
        newAccount.xpubHashId = account.xpubHashId
        return newAccount
    }

    func updateAccountName(_ name: String) {
        account.name = name
        AccountsRepository.shared.upsert(account)
        AnalyticsManager.shared.renameWallet()
    }

    func updateAccountAskEphemeral(_ enabled: Bool) {
        account.askEphemeral = enabled
        AccountsRepository.shared.upsert(account)
    }

    func updateAccountAttempts(_ value: Int) {
        account.attempts = value
        AccountsRepository.shared.upsert(account)
    }
}
