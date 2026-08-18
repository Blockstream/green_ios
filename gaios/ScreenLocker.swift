import Foundation
import UIKit
import core

class ScreenLocker {

    public static let shared = ScreenLocker()
    private var countdownInterval: CFAbsoluteTime?
    // Indicates whether or not the user is currently locked out of the app.
    private var isScreenLockLocked: Bool = false

    // App is inactive or in background
    var appIsInactiveOrBackground: Bool = false {
        didSet {
            // Setter for property indicating that the app is either
            // inactive or in the background, e.g. not "foreground and active."
            if appIsInactiveOrBackground {
                startCountdown()
            } else {
                activateBasedOnCountdown()
                countdownInterval = nil
            }
        }
    }

    // App is in background
    var appIsInBackground: Bool = false {
        didSet {
            if appIsInBackground {
                startCountdown()
            } else {
                activateBasedOnCountdown()
            }
        }
    }

    init() {
        clear()
        appIsInactiveOrBackground = UIApplication.shared.applicationState != UIApplication.State.active
    }

    func clear() {
        countdownInterval = nil
        isScreenLockLocked = false
        hideLockWindow()
    }

    func startCountdown() {
        if self.countdownInterval == nil {
            self.countdownInterval = CFAbsoluteTimeGetCurrent()
        }
    }

    func activateBasedOnCountdown() {
        if self.isScreenLockLocked {
            // Screen lock is already activated.
            return
        }
        guard let countdownInterval = self.countdownInterval else {
            // We became inactive, but never started a countdown.
            return
        }
        let countdown: TimeInterval = CFAbsoluteTimeGetCurrent() - countdownInterval
        for (id, wm) in WalletsRepository.shared.wallets {
            let altimeout = wm.prominentSession?.settings?.altimeout ?? 5
            if Int(countdown) >= altimeout * 60 {
                if id == WalletsStorage.shared.current?.id {
                    self.isScreenLockLocked = true
                }
            }
        }
    }

    func applicationDidBecomeActive() {
        appIsInactiveOrBackground = false
        ensureUI()
    }

    func applicationWillResignActive() {
        appIsInactiveOrBackground = true
        ensureUI()
    }

    func applicationWillEnterForeground() {
        appIsInBackground = false
        ensureUI()
        Task { [weak self] in
            await self?.resumeNetworks()
        }
    }

    var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    func applicationDidEnterBackground() {
        appIsInBackground = true
        self.backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "Network Tasks") {
            UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
            self.backgroundTaskID = UIBackgroundTaskIdentifier.invalid
        }
        ensureUI()
        Task {
            await self.pauseNetworks()
            guard backgroundTaskID != .invalid else { return }
            await UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
            self.backgroundTaskID = UIBackgroundTaskIdentifier.invalid
        }
    }

    func showLockWindow() {
        guard ScreenLockWindow.shared.windowScene != nil else { return }
        // Hide Root Window
        UIApplication.shared.mainApplicationWindow?.isHidden = true
        ScreenLockWindow.shared.show()
    }

    func hideLockWindow() {
        ScreenLockWindow.shared.hide()
        // Show Root Window
        guard let mainWindow = UIApplication.shared.mainApplicationWindow else { return }
        mainWindow.isHidden = false
        // By calling makeKeyAndVisible we ensure the rootViewController becomes first responder.
        // In the normal case, that means the ViewController will call `becomeFirstResponder`
        // on the vc on top of its navigation stack.
        mainWindow.makeKeyAndVisible()
    }

    func ensureUI() {
        if isScreenLockLocked {
            if appIsInactiveOrBackground {
                showLockWindow()
            } else {
                unlock()
            }
        } else if !self.appIsInactiveOrBackground {
            // App is inactive or background.
            hideLockWindow()
        } else {
            showLockWindow()
        }
    }

    func unlock() {
        if self.appIsInactiveOrBackground {
            return
        }
        DispatchQueue.main.async {
            self.clear()
            Task { await self.logout() }
        }
    }

    func logout() async {
        guard let mainWallet = WalletsStorage.shared.current else {
            return
        }
        if let wm = WalletsRepository.shared.get(for: mainWallet.id) {
            await shutdown(walletId: mainWallet.id, wm: wm)
        }
        await MainActor.run {
            WalletNavigator.navLogout(walletId: mainWallet.isEphemeral ? nil : mainWallet.id)
        }
    }

    /// Disconnect and remove a wallet from the repository so login never reuses an empty WM.
    private func shutdown(walletId: String, wm: WalletManager) async {
        if let wallet = WalletsStorage.shared.get(for: walletId), wallet.isHW {
            try? await BleHwManager.shared.disconnect()
        }
        await wm.disconnect()
        if wm.isEphemeral, let wallet = WalletsStorage.shared.get(for: walletId) {
            await WalletsStorage.shared.remove(wallet)
        }
        WalletsRepository.shared.delete(for: walletId)
    }

    func resumeNetworks() async {
        logger.info("ScreenLocker resumeNetworks")
        guard let idleStartedAt = countdownInterval else {
            // We became inactive, but never started a countdown.
            return
        }
        let countdown: TimeInterval = CFAbsoluteTimeGetCurrent() - idleStartedAt
        // Snapshot before mutating the repository.
        for (walletId, wm) in Array(WalletsRepository.shared.wallets) where wm.logged {
            let altimeout = wm.prominentSession?.settings?.altimeout ?? 5
            if Int(countdown) >= altimeout * 60 {
                await shutdown(walletId: walletId, wm: wm)
            } else {
                await wm.resume()
            }
        }
    }

    func pauseNetworks() async {
        logger.info("ScreenLocker pauseNetworks")
        for wm in WalletsRepository.shared.wallets.values {
            if wm.logged {
                await wm.pause()
            }
        }
    }
}
