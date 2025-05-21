import Foundation
import core
import gdk
import greenaddress

enum OnBoardingFlowType {
    case add
    case restore
    case watchonly
}

enum OnBoardingChainType {
    case mainnet
    case testnet
}

class OnboardViewModel {
    static var flowType: OnBoardingFlowType = .add
    static var chainType: OnBoardingChainType = .mainnet
    static var credentials: Credentials?
    static var restoreAccountId: String?

    func getBIP39WordList(_ mnemonic: String) -> [String] {
        greenaddress.getBIP39WordList()
    }

    func validateMnemonic(_ mnemonic: String) async throws {
        if let validated = try? greenaddress.validateMnemonic(mnemonic: mnemonic),
           validated {
            return
        }
        throw LoginError.invalidMnemonic()
    }

    func getXpubHashId(session: SessionManager, credentials: Credentials) async throws -> String? {
        try await session.connect()
        let walletId = try session.walletIdentifier(credentials: credentials)
        return walletId?.xpubHashId
    }

    func checkWalletsJustRestored(wm: WalletManager, credentials: Credentials) async throws {
        // Avoid to restore an existing wallets
        let xpub = try await getXpubHashId(session: wm.prominentSession!, credentials: credentials)
        let prevAccounts = AccountsRepository.shared.find(xpubHashId: xpub ?? "")?
            .filter { $0.networkType == wm.account.networkType &&
                !$0.isHW && !$0.isWatchonly } ?? []
        if let prevAccount = prevAccounts.first, prevAccount.id != wm.account.id {
            throw LoginError.walletsJustRestored()
        }
    }

    func addPinData(wallet: WalletManager, credentials: Credentials, pin: String) async throws -> Credentials {
        guard let session = wallet.prominentSession else {
            throw LoginError.connectionFailed("")
        }
        try await session.connect()
        let encryptParams = EncryptWithPinParams(pin: pin, credentials: credentials)
        let encrypted = try await session.encryptWithPin(encryptParams)
        try AuthenticationTypeHandler.setPinData(method: .AuthKeyPIN, pinData: encrypted.pinData, extraData: nil, for: wallet.account.keychain)
        let pinData = try AuthenticationTypeHandler.getPinData(method: .AuthKeyPIN, for: wallet.account.keychain)
        let decryptParams = DecryptWithPinParams(pin: pin, pinData: pinData)
        return try await session.decryptWithPin(decryptParams)
    }

    func addBiometricData(wallet: WalletManager, credentials: Credentials) async throws -> Credentials {
        var pinData = PinData(encryptedData: "", pinIdentifier: UUID().uuidString, salt: "", encryptedBiometric: nil, plaintextBiometric: nil)
        try AuthenticationTypeHandler.setPinData(method: .AuthKeyBiometric, pinData: pinData, extraData: credentials.mnemonic, for: wallet.account.keychain)
        pinData = try AuthenticationTypeHandler.getPinData(method: .AuthKeyBiometric, for: wallet.account.keychain)
        return Credentials(mnemonic: pinData.plaintextBiometric, pinData: pinData)
    }

    func restoreWallet(credentials: Credentials, pin: String?) async throws -> WalletManager {
        var credentials = credentials
        try await self.validateMnemonic(credentials.mnemonic ?? "")
        let account = try await createAccount()
        let wallet = WalletsRepository.shared.getOrAdd(for: account)
        wallet.popupResolver = await PopupResolver()
        wallet.hwInterfaceResolver = HwPopupResolver()
        // setup auth
        if let pin = pin {
            credentials = try await addPinData(wallet: wallet, credentials: credentials, pin: pin)
        } else {
            credentials = try await addBiometricData(wallet: wallet, credentials: credentials)
        }
        try await checkWalletsJustRestored(wm: wallet, credentials: credentials)
        // login
        let walletIdentifier = try wallet.prominentSession?.walletIdentifier(credentials: credentials)
        var lightningCredentials: Credentials?
        if AppSettings.shared.experimental && !wallet.testnet {
            lightningCredentials = try wallet.deriveLightningCredentials(from: credentials)
        }
        try await wallet.login(
            credentials: credentials,
            lightningCredentials: lightningCredentials,
            device: nil,
            masterXpub: nil,
            fullRestore: true,
            parentWalletId: walletIdentifier)
        AnalyticsManager.shared.importWallet(account: wallet.account)
        // check existing lightning subaccount
        if let lightningCredentials = lightningCredentials,
            let lightningSession = wallet.lightningSession,
            lightningSession.logged {
            let balance = try await lightningSession.getBalance(subaccount: 0, numConfs: 0)
            let txs = try await lightningSession.transactions(subaccount: 0)
            if txs.list.isEmpty && balance[AssetInfo.btcId] ?? 0 == 0 {
                // remove session
                try? await lightningSession.disconnect()
                _ = try? await wallet.subaccounts()
            } else {
                // add lightning auth into keychain
                try? AuthenticationTypeHandler.setCredentials(method: .AuthKeyLightning, credentials: lightningCredentials, for: account.keychainLightning)
            }
        }
        // cleanup previous restored account
        if let restoreAccountId = OnboardViewModel.restoreAccountId {
            if let account = AccountsRepository.shared.get(for: restoreAccountId) {
                wallet.account.name = account.name
                await AccountsRepository.shared.remove(account)
            }
        }
        return wallet
    }

    func createWallet(pin: String?) async throws -> WalletManager {
        let account = try await createAccount()
        let mnemonic = try generateMnemonic12()
        var credentials = Credentials(mnemonic: mnemonic)
        let wallet = WalletsRepository.shared.getOrAdd(for: account)
        if let pin = pin {
            credentials = try await addPinData(wallet: wallet, credentials: credentials, pin: pin)
        } else {
            credentials = try await addBiometricData(wallet: wallet, credentials: credentials)
        }
        try await wallet.create(credentials)
        return wallet
    }

    func createAccount() async throws -> Account {
        let testnet = OnboardViewModel.chainType == .testnet ? true : false
        let name = AccountsRepository.shared.getUniqueAccountName(testnet: testnet)
        let mainNetwork: NetworkSecurityCase = testnet ? .testnetSS : .bitcoinSS
        return Account(name: name, network: mainNetwork)
    }

    func setupPinWallet(credentials: Credentials, pin: String) async throws -> WalletManager {
        guard let wm = WalletManager.current,
            let session = wm.prominentSession
        else { throw LoginError.failed() }
        try await session.connect()
        try await wm.account.addPin(session: session, pin: pin, credentials: credentials)
        wm.account.attempts = 0
        return wm
    }
}
