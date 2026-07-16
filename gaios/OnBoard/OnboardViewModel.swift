import Foundation
import core

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
    static var restoreWalletId: String?

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

    func checkWalletsJustRestored(wallet: Wallet, credentials: Credentials) async throws {
        // Avoid to restore an existing wallets
        let session = SessionManager(wallet.networkId)
        let xpub = try await getXpubHashId(session: session, credentials: credentials)
        let prevAccounts = WalletsStorage.shared.find(xpubHashId: xpub ?? "")?
            .filter {
                $0.networkId == wallet.networkId &&
                !$0.isHW && !$0.isWatchonly &&
                $0.id != wallet.id &&
                $0.id != OnboardViewModel.restoreWalletId } ?? []
        if !prevAccounts.isEmpty {
            if prevAccounts.count == 1, let name = prevAccounts.first?.name {
                throw LoginError.walletsJustRestored(String(format: "id_wallet_already_restored_s".localized, name))
            }
            throw LoginError.walletsJustRestored()
        }
    }

    func addPinData(wm: WalletManager, wallet: Wallet, credentials: Credentials, pin: String) async throws -> Credentials {
        guard let session = wm.prominentSession else {
            throw GaError.GenericError("Failed to get session")
        }
        try await session.connect()
        let encryptParams = EncryptWithPinParams(pin: pin, credentials: credentials)
        let encrypted = try await session.encryptWithPin(encryptParams)
        try AuthenticationTypeHandler.setPinData(method: .AuthKeyPIN, pinData: encrypted.pinData, extraData: nil, for: wallet.keychain)
        let pinData = try AuthenticationTypeHandler.getPinData(method: .AuthKeyPIN, for: wallet.keychain)
        let decryptParams = DecryptWithPinParams(pin: pin, pinData: pinData)
        return try await session.decryptWithPin(decryptParams)
    }

    func addBiometricData(wm: WalletManager, wallet: Wallet, credentials: Credentials) async throws -> Credentials {
        var pinData = PinData(encryptedData: "", pinIdentifier: UUID().uuidString, salt: "", encryptedBiometric: nil, plaintextBiometric: nil)
        try AuthenticationTypeHandler.setPinData(method: .AuthKeyBiometric, pinData: pinData, extraData: credentials.mnemonic, for: wallet.keychain)
        pinData = try AuthenticationTypeHandler.getPinData(method: .AuthKeyBiometric, for: wallet.keychain)
        return Credentials(mnemonic: pinData.plaintextBiometric, pinData: pinData)
    }

    func restoreWallet(credentials: Credentials, pin: String?) async throws -> (Wallet, WalletManager) {
        var credentials = credentials
        try await self.validateMnemonic(credentials.mnemonic ?? "")
        var wallet = try await createWallet()
        let wm = WalletsRepository.shared.getOrAdd(for: wallet)
        wm.popupResolver = await PopupResolver()
        wm.hwInterfaceResolver = HwPopupResolver()
        // setup auth
        if let pin = pin {
            credentials = try await addPinData(wm: wm, wallet: wallet, credentials: credentials, pin: pin)
        } else {
            credentials = try await addBiometricData(wm: wm, wallet: wallet, credentials: credentials)
        }
        try await checkWalletsJustRestored(wallet: wallet, credentials: credentials)
        // login
        let boltzCredentials = try wm.deriveBoltzCredentials(from: credentials)
        let lightningCredentials = try wm.deriveLightningCredentials(from: credentials)
        // add boltz auth into keychain
        try? AuthenticationTypeHandler.setCredentials(method: .AuthKeyBoltz, credentials: boltzCredentials, for: wallet.keychain)
        let res = try await wm.login(
            credentials: credentials,
            lightningCredentials: lightningCredentials,
            boltzCredentials: boltzCredentials,
            device: nil,
            fullRestore: true,
            creation: false)
        wallet.applyLoginResult(res, credentials: credentials)
        // add lightning auth into keychain only if it successfully restored
        if wm.lightningSession?.logged == true {
            try? AuthenticationTypeHandler.setCredentials(method: .AuthKeyLightning, credentials: lightningCredentials, for: wallet.keychainLightning)
        } else {
            wallet.removeAuthentication(.AuthKeyLightning)
        }
        // cleanup previous restored account
        if let restoreWalletId = OnboardViewModel.restoreWalletId {
            if let restoredWallet = WalletsStorage.shared.get(for: restoreWalletId) {
                wallet.name = restoredWallet.name
                await WalletsStorage.shared.remove(restoredWallet)
            }
        }
        // notify analytics
        AnalyticsManager.shared.importWallet(wallet: wallet)
        return (wallet, wm)
    }

    func createWallet(pin: String?) async throws -> (Wallet, WalletManager) {
        var wallet = try await createWallet()
        let mnemonic = try generateMnemonic12()
        var credentials = Credentials(mnemonic: mnemonic)
        let wm = WalletsRepository.shared.getOrAdd(for: wallet)
        if let pin = pin {
            credentials = try await addPinData(wm: wm, wallet: wallet, credentials: credentials, pin: pin)
        } else {
            credentials = try await addBiometricData(wm: wm, wallet: wallet, credentials: credentials)
        }
        let boltzCredentials = try wm.deriveBoltzCredentials(from: credentials)
        try AuthenticationTypeHandler.setCredentials(method: .AuthKeyBoltz, credentials: boltzCredentials, for: wallet.keychain)
        let res = try await wm.login(
            credentials: credentials,
            lightningCredentials: nil,
            boltzCredentials: boltzCredentials,
            device: nil,
            fullRestore: false,
            creation: true)
        wallet.applyLoginResult(res, credentials: credentials)
        return (wallet, wm)
    }

    func createWallet() async throws -> Wallet {
        let testnet = OnboardViewModel.chainType == .testnet ? true : false
        let name = WalletsStorage.shared.getUniqueAccountName(testnet: testnet)
        let mainNetwork: NetworkId = testnet ? .electrumTestnet : .electrumMainnet
        return Wallet(name: name, network: mainNetwork)
    }

    func setupPinWallet(credentials: Credentials, pin: String, wallet: Wallet, wm: WalletManager) async throws -> (Wallet, WalletManager) {
        guard let session = wm.prominentSession else {
            throw GaError.GenericError("Failed to get session")
        }
        try await session.connect()
        try await wallet.addPin(session: session, pin: pin, credentials: credentials)
        var wallet = wallet
        wallet.attempts = 0
        WalletsStorage.shared.upsert(wallet)
        return (wallet, wm)
    }
}
