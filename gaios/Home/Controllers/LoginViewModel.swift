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
        let session = SessionManager(account.gdkNetwork)
        let pinData = try self.account.auth(usingAuth)
        let pin = withPIN ?? pinData.plaintextBiometric
        let decryptData = DecryptWithPinParams(pin: pin ?? "", pinData: pinData)
        try await session.connect()
        let credentials = try await session.decryptWithPin(decryptData)
        return credentials
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
        let wm = WalletsRepository.shared.getOrAdd(for: account)
        wm.popupResolver = await PopupResolver()
        wm.hwInterfaceResolver = await HwPopupResolver()
        let lightningCredentials = Credentials(mnemonic: try wm.getLightningMnemonic(credentials: credentials), bip39Passphrase: bip39passphrase)
        let walletIdentifier = try wm.prominentSession?.walletIdentifier(credentials: credentials)
        try await wm.login(credentials: credentials, lightningCredentials: lightningCredentials, parentWalletId: walletIdentifier)
        account = wm.account
        if withPIN != nil {
            account.attempts = 0
        }
        AccountsRepository.shared.current = account
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

    func loginWithLightningShortcut() async throws {
        AnalyticsManager.shared.loginWalletStart()
        let wm = WalletsRepository.shared.getOrAdd(for: account)
        wm.popupResolver = await PopupResolver()
        wm.hwInterfaceResolver = await HwPopupResolver()
        try await auth()
        let credentials = try AuthenticationTypeHandler.getAuthKeyLightning(forNetwork: account.keychain)
        _ = try await wm.login(credentials: credentials, lightningCredentials: credentials, parentWalletId: account.walletIdentifier)
        AccountsRepository.shared.current = account
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
