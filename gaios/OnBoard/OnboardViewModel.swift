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

    func checkWalletsJustRestored(account: Account, credentials: Credentials) async throws {
        // Avoid to restore an existing wallets
        let xpub = try await getXpubHashId(session: SessionManager(account.networkType), credentials: credentials)
        let prevAccounts = AccountsRepository.shared.find(xpubHashId: xpub ?? "")?
            .filter {
                $0.networkType == account.networkType &&
                !$0.isHW && !$0.isWatchonly &&
                $0.id != account.id &&
                $0.id != OnboardViewModel.restoreAccountId } ?? []
        if !prevAccounts.isEmpty {
            throw LoginError.walletsJustRestored()
        }
    }

    func addPinData(wallet: WalletManager, account: Account, credentials: Credentials, pin: String) async throws -> Credentials {
        guard let session = wallet.prominentSession else {
            throw LoginError.connectionFailed("Invalid session")
        }
        try await session.connect()
        let encryptParams = EncryptWithPinParams(pin: pin, credentials: credentials)
        let encrypted = try await session.encryptWithPin(encryptParams)
        try AuthenticationTypeHandler.setPinData(method: .AuthKeyPIN, pinData: encrypted.pinData, extraData: nil, for: account.keychain)
        let pinData = try AuthenticationTypeHandler.getPinData(method: .AuthKeyPIN, for: account.keychain)
        let decryptParams = DecryptWithPinParams(pin: pin, pinData: pinData)
        return try await session.decryptWithPin(decryptParams)
    }

    func addBiometricData(wallet: WalletManager, account: Account, credentials: Credentials) async throws -> Credentials {
        var pinData = PinData(encryptedData: "", pinIdentifier: UUID().uuidString, salt: "", encryptedBiometric: nil, plaintextBiometric: nil)
        try AuthenticationTypeHandler.setPinData(method: .AuthKeyBiometric, pinData: pinData, extraData: credentials.mnemonic, for: account.keychain)
        pinData = try AuthenticationTypeHandler.getPinData(method: .AuthKeyBiometric, for: account.keychain)
        return Credentials(mnemonic: pinData.plaintextBiometric, pinData: pinData)
    }

    func restoreWallet(credentials: Credentials, pin: String?) async throws -> (Account, WalletManager) {
        var credentials = credentials
        try await self.validateMnemonic(credentials.mnemonic ?? "")
        var account = try await createAccount()
        let wallet = WalletsRepository.shared.getOrAdd(for: account)
        wallet.popupResolver = await PopupResolver()
        wallet.hwInterfaceResolver = HwPopupResolver()
        // setup auth
        if let pin = pin {
            credentials = try await addPinData(wallet: wallet, account: account, credentials: credentials, pin: pin)
        } else {
            credentials = try await addBiometricData(wallet: wallet, account: account, credentials: credentials)
        }
        try await checkWalletsJustRestored(account: account, credentials: credentials)
        // login
        let walletIdentifier = try wallet.prominentSession?.walletIdentifier(credentials: credentials)
        let boltzCredentials = try wallet.deriveBoltzCredentials(from: credentials)
        // add boltz auth into keychain
        try? AuthenticationTypeHandler.setCredentials(method: .AuthKeyBoltz, credentials: boltzCredentials, for: account.keychain)
        let res = try await wallet.login(
            credentials: credentials,
            lightningCredentials: nil,
            boltzCredentials: boltzCredentials,
            device: nil,
            masterXpub: nil,
            fullRestore: true,
            parentWalletId: walletIdentifier)
        account.xpubHashId = res?.xpubHashId
        account.walletHashId = res?.walletHashId
        // restore previous swaps
        if let liquidSubaccount = wallet.liquidSubaccounts.first, let xpubHashId = res?.xpubHashId {
            if let liquidAddress = try await liquidSubaccount.session?.getReceiveAddress(subaccount: liquidSubaccount.pointer).address {
                try await wallet.lwkSession?.restoreSwaps(address: liquidAddress, xpubHashId: xpubHashId)
            }
        }
        // cleanup previous restored account
        if let restoreAccountId = OnboardViewModel.restoreAccountId {
            if let restoredAccount = AccountsRepository.shared.get(for: restoreAccountId) {
                account.name = restoredAccount.name
                await AccountsRepository.shared.remove(restoredAccount)
            }
        }
        // notify analytics
        AnalyticsManager.shared.importWallet(account: account)
        return (account, wallet)
    }

    func createWallet(pin: String?) async throws -> (Account, WalletManager) {
        var account = try await createAccount()
        let mnemonic = try generateMnemonic12()
        var credentials = Credentials(mnemonic: mnemonic)
        let wallet = WalletsRepository.shared.getOrAdd(for: account)
        if let pin = pin {
            credentials = try await addPinData(wallet: wallet, account: account, credentials: credentials, pin: pin)
        } else {
            credentials = try await addBiometricData(wallet: wallet, account: account, credentials: credentials)
        }
        let boltzCredentials = try wallet.deriveBoltzCredentials(from: credentials)
        try AuthenticationTypeHandler.setCredentials(method: .AuthKeyBoltz, credentials: boltzCredentials, for: account.keychain)
        let walletIdentifier = try wallet.prominentSession?.walletIdentifier(credentials: credentials)
        let res = try await wallet.login(
            credentials: credentials,
            lightningCredentials: nil,
            boltzCredentials: boltzCredentials,
            device: nil,
            masterXpub: nil,
            fullRestore: false,
            parentWalletId: walletIdentifier)
        account.xpubHashId = res?.xpubHashId
        account.walletHashId = res?.walletHashId
        return (account, wallet)
    }

    func createAccount() async throws -> Account {
        let testnet = OnboardViewModel.chainType == .testnet ? true : false
        let name = AccountsRepository.shared.getUniqueAccountName(testnet: testnet)
        let mainNetwork: NetworkSecurityCase = testnet ? .testnetSS : .bitcoinSS
        return Account(name: name, network: mainNetwork)
    }

    func setupPinWallet(credentials: Credentials, pin: String, account: Account, wm: WalletManager) async throws -> (Account, WalletManager) {
        guard let session = wm.prominentSession
        else { throw LoginError.failed() }
        try await session.connect()
        try await account.addPin(session: session, pin: pin, credentials: credentials)
        var account = account
        account.attempts = 0
        AccountsRepository.shared.upsert(account)
        return (account, wm)
    }
}
