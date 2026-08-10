import Foundation
import LocalAuthentication

import core

class LoginViewModel {

    var wallet: Wallet
    var autologin: Bool = true

    init(wallet: Wallet, autologin: Bool = true) {
        self.wallet = wallet
        self.autologin = autologin
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
        let pinData = try AuthenticationTypeHandler.getPinData(method: usingAuth, for: wallet.keychain)
        if !pinData.encryptedData.isEmpty {
            // need decrypt with pin server
            let pin = withPIN ?? pinData.plaintextBiometric
            let decryptData = DecryptWithPinParams(pin: pin ?? "", pinData: pinData)
            let wm = WalletsRepository.shared.getOrAdd(for: wallet)
            let session = wm.prominentNetworkBackend?.session
            try await session?.connect()
            guard let res = try await session?.decryptWithPin(decryptData) else {
                throw LoginError.failed("Invalid session")
            }
            return res
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
            wallet = updateEphemeralAccount(from: credentials)
        }
        _ = try await loginWithCredentials(credentials: credentials)
        if withPIN != nil {
            wallet.attempts = 0
        }
    }

    func getBoltzCredentials(wm: WalletManager, mainCredentials: Credentials) throws -> Credentials {
        let isBip39 = !mainCredentials.bip39Passphrase.isNilOrEmpty
        let storedBoltz = try? AuthenticationTypeHandler.getCredentials(method: .AuthKeyBoltz, for: wallet.keychain)
        if isBip39 {
            // Reuse keychain boltz key only when it was derived with the same bip39 passphrase
            if let storedBoltz,
               !storedBoltz.bip39Passphrase.isNilOrEmpty,
               storedBoltz.bip39Passphrase == mainCredentials.bip39Passphrase {
                return storedBoltz
            } else {
                // Missing, no bip39, or different passphrase: derive without storing
                return try wm.deriveBoltzCredentials(from: mainCredentials)
            }
        } else if let storedBoltz {
            return storedBoltz
        } else {
            // Non-bip39: derive and persist on keychain
            let boltzCredentials = try wm.deriveBoltzCredentials(from: mainCredentials)
            try AuthenticationTypeHandler.setCredentials(method: .AuthKeyBoltz, credentials: boltzCredentials, for: wallet.keychain)
            return boltzCredentials
        }
    }

    func loginWithCredentials(credentials: Credentials) async throws -> WalletManager {
        let wm = WalletsRepository.shared.getOrAdd(for: wallet)
        wm.popupResolver = await PopupResolver()
        wm.hwInterfaceResolver = HwPopupResolver()
        // Derive passphrase wallet credentials transiently instead of reading the parent's key, if bip39 ephemeral
        let isEphemeral = !(credentials.bip39Passphrase ?? "").isEmpty
        let lightningCredentials = isEphemeral
            ? try? wm.deriveLightningCredentials(from: credentials)
            : try? AuthenticationTypeHandler.getCredentials(method: .AuthKeyLightning, for: wallet.keychainLightning)
        let boltzCredentials = try? getBoltzCredentials(wm: wm, mainCredentials: credentials)
        let res = try await wm.login(
            credentials: credentials,
            lightningCredentials: lightningCredentials,
            boltzCredentials: boltzCredentials,
            device: nil,
            fullRestore: false,
            creation: false,
            parentXpub: credentials.isWatchonly ? wallet.xpubHashId : nil)
        wallet.applyLoginResult(res, credentials: credentials)
        WalletsStorage.shared.current = wallet
        return wm
    }

    fileprivate func updateEphemeralAccount(from credentials: Credentials) -> Wallet {
        let networkId = wallet.networkId.testnet ? NetworkId.electrumTestnet : NetworkId.electrumMainnet
        var newAccount = Wallet(name: wallet.name, network: networkId, keychain: wallet.keychain)
        newAccount.isEphemeral = true
        newAccount.askEphemeral = true
        newAccount.attempts = wallet.attempts
        newAccount.xpubHashId = wallet.xpubHashId
        return newAccount
    }

    func updateAccountName(_ name: String) {
        wallet.name = name
        WalletsStorage.shared.upsert(wallet)
        AnalyticsManager.shared.renameWallet()
    }

    func updateAccountAskEphemeral(_ enabled: Bool) {
        wallet.askEphemeral = enabled
        WalletsStorage.shared.upsert(wallet)
    }

    func updateAccountAttempts(_ value: Int) {
        wallet.attempts = value
        WalletsStorage.shared.upsert(wallet)
    }
}
