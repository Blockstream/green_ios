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
                if id == wm.account.id {
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
        // Hide Root Window
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.window?.isHidden = true
        ScreenLockWindow.shared.show()
    }

    func hideLockWindow() {
        ScreenLockWindow.shared.hide()
        // Show Root Window
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.window?.isHidden = false
        // By calling makeKeyAndVisible we ensure the rootViewController becomes first responder.
        // In the normal case, that means the ViewController will call `becomeFirstResponder`
        // on the vc on top of its navigation stack.
        appDelegate?.window?.makeKeyAndVisible()
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
            let account = AccountsRepository.shared.current
            AccountNavigator.navLogout(accountId: account?.id)
        }
    }

    func resumeNetworks() async {
        logger.info("ScreenLocker resumeNetworks")
        guard let countdownInterval = self.countdownInterval else {
            // We became inactive, but never started a countdown.
            return
        }
        let countdown: TimeInterval = CFAbsoluteTimeGetCurrent() - countdownInterval
        for wm in WalletsRepository.shared.wallets.values {
            if wm.logged {
                let altimeout = wm.prominentSession?.settings?.altimeout ?? 5
                if Int(countdown) >= altimeout * 60 {
                    await wm.disconnect()
                } else {
                    await wm.resume()
                }
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
