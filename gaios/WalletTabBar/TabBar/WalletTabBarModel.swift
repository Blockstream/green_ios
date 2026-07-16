import UIKit
import core

import AsyncAlgorithms
import greenaddress

enum SecurityState {
    case normal
    case alerted
}

class WalletTabBarModel {

    var wm: WalletManager
    var mainWallet: Wallet
    var isCreated: Bool
    var isRestored: Bool
    var securityState = SecurityState.alerted
    var walletDataModel: WalletDataModel
    private var analyticsDone = false

    init(wm: WalletManager, mainWallet: Wallet, isCreated: Bool, isRestored: Bool) {
        self.wm = wm
        self.mainWallet = mainWallet
        self.isCreated = isCreated
        self.isRestored = isRestored
        self.walletDataModel = WalletDataModel(wm: wm, mainWallet: mainWallet)
        if let lwkBoltzBackend = wm.lwkBoltzBackend {
            self.wm.swapMonitor = SwapMonitor(xpubHashId: mainWallet.xpubHashId ?? "", lwkBoltzBackend: lwkBoltzBackend)
        }
    }

    deinit {
        Task { [walletDataModel] in
            await walletDataModel.shutdown()
        }
    }

    @MainActor func tabTransactVC() -> TabTransactVC {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        let viewModel = TabTransactVM(walletDataModel: walletDataModel, wm: wm, mainWallet: mainWallet)
        return storyboard.instantiateViewController(identifier: "TabTransactVC") { coder in
            TabTransactVC(coder: coder, viewModel: viewModel)
        }
    }
    @MainActor func tabSecurityVC() -> TabSecurityVC {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        let viewModel = TabSecurityVM(walletDataModel: walletDataModel, wm: wm, mainWallet: mainWallet)
        return storyboard.instantiateViewController(identifier: "TabSecurityVC") { coder in
            TabSecurityVC(coder: coder, viewModel: viewModel)
        }
    }
    @MainActor func tabSettingsVC() -> TabSettingsVC {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        let viewModel = TabSettingsVM(walletDataModel: walletDataModel, wm: wm, mainWallet: mainWallet)
        return storyboard.instantiateViewController(identifier: "TabSettingsVC") { coder in
            TabSettingsVC(coder: coder, viewModel: viewModel)
        }
    }
    @MainActor func tabHomeVC() -> TabHomeVC {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        let viewModel = TabHomeVM(walletDataModel: walletDataModel, wm: wm, mainWallet: mainWallet)
        return storyboard.instantiateViewController(identifier: "TabHomeVC") { coder in
            TabHomeVC(coder: coder, viewModel: viewModel)
        }
    }
    func registerNotifications() async throws {
        guard let token = UserDefaults(suiteName: Bundle.main.appGroup)?.string(forKey: "token") else {
            throw GaError.GenericError("No token")
        }
        guard let xpubHashId = mainWallet.xpubHashId else {
            throw GaError.GenericError("No xpub")
        }
        /// Register notification token for meld and lwk on sanbox
        if Bundle.main.dev || Meld.isSandboxEnvironment {
            try? await Meld().registerToken(fcmToken: token, externalCustomerId: xpubHashId, notificationUrl: Meld.MELD_NOTIFICATIONS_URL_SANDBOX)
        }
        /// Register notification token for meld and lwk on production
        if !Bundle.main.dev || !Meld.isSandboxEnvironment {
            try? await Meld().registerToken(fcmToken: token, externalCustomerId: xpubHashId, notificationUrl: Meld.MELD_NOTIFICATIONS_URL_PRODUCTION)
        }
        /// Register notification token for lightning
        if let lightningSession = wm.lightningSession, lightningSession.logged {
            try? await lightningSession.registerNotification(fcmToken: token, xpubHashId: xpubHashId)
        }
    }
    func startSwapMonitor() async throws {
        _ = await wm.awaitLwkSession()
        if isRestored {
            let liquidAddress = await getAddress(subaccount: wm.liquidSubaccounts.first)
            let bitcoinAddress = await getAddress(subaccount: wm.bitcoinSubaccounts.first)
            if let liquidAddress, let bitcoinAddress {
                try? await wm.swapMonitor?.restoreSwaps(bitcoinAddress: bitcoinAddress, liquidAddress: liquidAddress)
            }
        }
        try await wm.swapMonitor?.start()
    }
    func getAddress(subaccount: Account?) async -> String? {
        guard let subaccount else { return nil }
        return try? await wm.accountBackend(subaccount).getReceiveAddress().address
    }
    func callAnalytics() {
        if analyticsDone == true { return }
        analyticsDone = true
        let fundedSubaccounts = wm
            .accounts
            .filter { (try? $0.isFunded(wm)) ?? false }
        let accountsTypes: String = Array(Set(fundedSubaccounts.map { $0.type.rawValue })).sorted().joined(separator: ",")
        AnalyticsManager.shared.activeWalletEnd(
            for: mainWallet,
            walletData: AnalyticsManager.WalletData(
                walletFunded: fundedSubaccounts.count > 0,
                accountsFunded: fundedSubaccounts.count,
                accounts: wm.accounts.count,
                accountsTypes: accountsTypes))
    }

    func startup() {
        Task {
            if isCreated && !wm.isHW && !wm.isWatchonly {
                BackupHelper.shared.addToBackupList(mainWallet.id)
            }
            await walletDataModel.triggerRefresh(features: [.subaccounts])
            await walletDataModel.triggerRefresh(features: [
                .alertCards, .promos, .priceChart,
                .balance, .settings, .security, .txs(reset: true)
            ])
        }
        Task(priority: .background) {
            callAnalytics()
            try? await registerNotifications()
            try? await startSwapMonitor()
            try? await wm.refreshRegistryIfNeeded()
        }
    }

    func showWelcomeStatus() -> Bool {
        if isCreated {
            isCreated = false
            return true
        }
        return false
    }
}
