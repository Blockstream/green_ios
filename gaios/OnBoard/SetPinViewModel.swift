import Foundation
import core
import gdk

class SetPinViewModel {

    var credentials: Credentials
    var testnet: Bool
    var restoredAccount: Account?

    init(credentials: Credentials, testnet: Bool, restoredAccount: Account? = nil) {
        self.credentials = credentials
        self.testnet = testnet
        self.restoredAccount = restoredAccount
    }

    func getXpubHashId(session: SessionManager) async throws -> String? {
        try await session.connect()
        let walletId = try session.walletIdentifier(credentials: self.credentials)
        return walletId?.xpubHashId
    }

    func restore(pin: String) async throws {
        let name = AccountsRepository.shared.getUniqueAccountName(testnet: testnet)
        let mainNetwork: NetworkSecurityCase = testnet ? .testnetSS : .bitcoinSS
        let defaultAccount = restoredAccount ?? Account(name: name, network: mainNetwork)
        let wm = WalletsRepository.shared.getOrAdd(for: defaultAccount)
        wm.popupResolver = await PopupResolver()
        try await checkWalletMismatch(wm: wm)
        try await checkWalletsJustRestored(wm: wm)
        let lightningCredentials = try wm.deriveLightningCredentials(from: self.credentials)
        let walletIdentifier = try wm.prominentSession?.walletIdentifier(credentials: credentials)
        try await wm.login(credentials: self.credentials, lightningCredentials: lightningCredentials, parentWalletId: walletIdentifier)
        wm.account.attempts = 0
        try await checkWalletMismatch(wm: wm)
        try await checkWalletsJustRestored(wm: wm)
        try await wm.account.addPin(session: wm.prominentSession!, pin: pin, credentials: credentials)
        AccountsRepository.shared.current = wm.account
        AnalyticsManager.shared.importWallet(account: wm.account)
    }

    func checkWalletMismatch(wm: WalletManager) async throws {
        // Avoid to restore an different wallet if restoredAccount is defined
        if let restoredAccount = restoredAccount {
            let xpub = try await getXpubHashId(session: wm.prominentSession!)
            if let xpubHashId = restoredAccount.xpubHashId, xpubHashId != xpub {
                throw LoginError.walletMismatch()
            }
        }
    }

    func checkWalletsJustRestored(wm: WalletManager) async throws {
        // Avoid to restore an existing wallets
        if restoredAccount == nil {
            let xpub = try await getXpubHashId(session: wm.prominentSession!)
            let prevAccounts = AccountsRepository.shared.find(xpubHashId: xpub ?? "")?
                .filter { $0.networkType == wm.account.networkType &&
                !$0.isHW && !$0.isWatchonly } ?? []
            if let prevAccount = prevAccounts.first, prevAccount.id != wm.account.id {
                throw LoginError.walletsJustRestored()
            }
        }
    }

    func create(pin: String) async throws {
        let name = AccountsRepository.shared.getUniqueAccountName(testnet: testnet)
        let mainNetwork: NetworkSecurityCase = testnet ? .testnetSS : .bitcoinSS
        let account = Account(name: name, network: mainNetwork)
        let wm = WalletsRepository.shared.getOrAdd(for: account)
        wm.popupResolver = await PopupResolver()
        try await wm.create(credentials)
        try await wm.account.addPin(session: wm.prominentSession!, pin: pin, credentials: credentials)
    }

    func setup(pin: String) async throws {
        guard let wm = WalletManager.current,
            let session = wm.prominentSession
        else { throw LoginError.failed() }
        try await session.connect()
        try await wm.account.addPin(session: session, pin: pin, credentials: credentials)
        wm.account.attempts = 0
    }

}
