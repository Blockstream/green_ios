import UIKit
import core
import gdk
import AsyncAlgorithms
import greenaddress

enum SecurityState {
    case normal
    case alerted
}

class WalletTabBarModel {

    var wallet: WalletManager
    var mainAccount: Account
    var isFirstLoad: Bool
    var securityState = SecurityState.alerted
    var walletDataModel: WalletDataModel
    private var analyticsDone = false

    init(wallet: WalletManager, mainAccount: Account, isFirstLoad: Bool) {
        self.wallet = wallet
        self.mainAccount = mainAccount
        self.isFirstLoad = isFirstLoad
        self.walletDataModel = WalletDataModel(wallet: wallet, mainAccount: mainAccount)
        if let lwkSession = wallet.lwkSession {
            self.wallet.swapMonitor = SwapMonitor(mainAccount: mainAccount, lwkSession: lwkSession)
        }
    }

    deinit {
        Task { [walletDataModel] in
            await walletDataModel.shutdown()
        }
    }
    
    @MainActor func tabTransactVC() -> TabTransactVC {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        let viewModel = TabTransactVM(walletDataModel: walletDataModel, wallet: wallet, mainAccount: mainAccount)
        return storyboard.instantiateViewController(identifier: "TabTransactVC") { coder in
            TabTransactVC(coder: coder, viewModel: viewModel)
        }
    }
    @MainActor func tabSecurityVC() -> TabSecurityVC {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        let viewModel = TabSecurityVM(walletDataModel: walletDataModel, wallet: wallet, mainAccount: mainAccount)
        return storyboard.instantiateViewController(identifier: "TabSecurityVC") { coder in
            TabSecurityVC(coder: coder, viewModel: viewModel)
        }
    }
    @MainActor func tabSettingsVC() -> TabSettingsVC {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        let viewModel = TabSettingsVM(walletDataModel: walletDataModel, wallet: wallet, mainAccount: mainAccount)
        return storyboard.instantiateViewController(identifier: "TabSettingsVC") { coder in
            TabSettingsVC(coder: coder, viewModel: viewModel)
        }
    }
    @MainActor func tabHomeVC() -> TabHomeVC {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        let viewModel = TabHomeVM(walletDataModel: walletDataModel, wallet: wallet, mainAccount: mainAccount)
        return storyboard.instantiateViewController(identifier: "TabHomeVC") { coder in
            TabHomeVC(coder: coder, viewModel: viewModel)
        }
    }
    func registerNotifications() async throws {
        guard let token = UserDefaults(suiteName: Bundle.main.appGroup)?.string(forKey: "token") else {
            throw GaError.GenericError("No token")
        }
        guard let xpubHashId = mainAccount.xpubHashId else {
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
        /// Register notification token for breez lightning
        if let lightningSession = wallet.lightningSession, lightningSession.logged {
            try? await lightningSession.registerNotification(token: token, xpubHashId: xpubHashId)
            _ = lightningSession.lightBridge?.updateLspInformation()
        }
    }

    func callAnalytics() {
        if analyticsDone == true { return }
        analyticsDone = true
        let fundedSubaccounts = wallet
            .subaccounts
            .filter({ $0.satoshi?.values.reduce(0, +) ?? 0 > 0 })
        let accountsTypes: String = Array(Set(fundedSubaccounts.map { $0.type.rawValue })).sorted().joined(separator: ",")
        AnalyticsManager.shared.activeWalletEnd(
            account: mainAccount,
            walletData: AnalyticsManager.WalletData(
                walletFunded: fundedSubaccounts.count > 0,
                accountsFunded: fundedSubaccounts.count,
                accounts: wallet.subaccounts.count,
                accountsTypes: accountsTypes))
    }
}
