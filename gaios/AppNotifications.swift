import UIKit
import gdk
import lightning
import UserNotifications
import FirebaseCore
import FirebaseMessaging
import core

class AppNotifications: NSObject {
    static let shared = AppNotifications()

    func registerForFcmPushNotifications() {
        // Remote Notifications from FCM
        if FirebaseApp.app() == nil {
            let filePath = Bundle.main.path(forResource: Bundle.main.googleServiceInfo, ofType: "plist")!
            let options = FirebaseOptions(contentsOfFile: filePath)
            FirebaseApp.configure(options: options!)
        }
        Messaging.messaging().delegate = self
    }

    func didRegisterForRemoteNotificationsWithDeviceToken(deviceToken: Data) {
        logger.info("Device Token: \(deviceToken)")
    }

    
    func checkNotificationStatusAndPromptIfNeeded(from viewController: UIViewController) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .denied:
                    // User has previously denied permission. Show custom dialog.
                    self.showManualEnableAlert(from: viewController)
                case .notDetermined:
                    // Permission hasn't been requested yet. Request it normally.
                    self.requestNotificationPermission()
                case .authorized, .provisional, .ephemeral:
                    // User has granted permission.
                    logger.info("Push notifications are enabled.")
                @unknown default:
                    break
                }
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                logger.error("Permission error: \(error.localizedDescription)")
            } else if granted {
                logger.info("Permission granted, now register for remote notifications.")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                logger.error("Permission denied at first request.")
            }
        }
    }

    private func showManualEnableAlert(from viewController: UIViewController) {
        let alertController = UIAlertController(
            title: "Enable Notifications",
            message: "Enable seamless background payments and real-time updates on your BTC purchases.",
            preferredStyle: .alert
        )
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        let settingsAction = UIAlertAction(title: "Enable in Settings", style: .default) { _ in
            // Redirect user to app's notification settings
            if let settingsURLString = UIApplication.notificationSettingsURLString,
               let settingsURL = URL(string: settingsURLString) {
                if UIApplication.shared.canOpenURL(settingsURL) {
                    UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
                }
            }
        }
        alertController.addAction(settingsAction)
        viewController.present(alertController, animated: true, completion: nil)
    }
}

extension AppNotifications: UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.info("Firebase failed registration token: \(String(describing: error), privacy: .public)")
    }

    // Called to let your app know which action was selected by the user for a given notification.
    @MainActor
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // User TAP on local/remote notification
        let content = response.notification.request.content.userInfo
        logger.info("userNotificationCenter didReceive \(content.description)")
        // For lightning notification
        let appData = content["app_data"] as? String
        // For meld notification
        let payload = content["payload"] as? String
        let txPayload = try? JSONDecoder().decode(MeldTransactionPayload.self, from: Data((payload ?? "").utf8))
        // Open Screen
        if let xpub = appData ?? txPayload?.externalCustomerId,
           let account = getAccount(xpub: xpub) {
            if let wm = WalletsRepository.shared.get(for: account), wm.logged {
                AccountNavigator.navLogged(accountId: account.id)
            } else {
                AccountNavigator.navLogin(accountId: account.id)
            }
        }
        completionHandler()
    }

    // Delivers a notification to an app running in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let content = notification.request.content.userInfo
        logger.info("userNotificationCenter willPresent \(content.description)")
        let notification = NSNotification.Name(rawValue: EventType.Transaction.rawValue)
        NotificationCenter.default.post(name: notification, object: nil, userInfo: nil)
        completionHandler([.sound, .banner])
    }

    func getAccount(xpub: String) -> Account? {
        let accounts = AccountsRepository.shared.accounts
        let mainAccounts = accounts.filter { $0.xpubHashId == xpub }
        return mainAccounts.first
    }
}

extension AppNotifications: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        logger.info("Firebase registration token: \(String(describing: fcmToken), privacy: .public)")
        let defaults = UserDefaults(suiteName: Bundle.main.appGroup)
        defaults?.setValue(fcmToken, forKey: "token")
    }
}
