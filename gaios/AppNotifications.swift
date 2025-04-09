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

    func requestRemoteNotificationPermissions(application: UIApplication, completion: (() -> Void)? = nil) {
        // Remote Notifications permissions
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { (granted, error) in
            if let error = error {
                logger.error("Register for push notifications fails with error: \(error.localizedDescription)")
                completion?()
                return
            }
            logger.info("Granter permission for push notifications")
            completion?()
        }
        application.registerForRemoteNotifications()
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
        guard let xpub = content["app_data"] as? String else {
            return
        }
        guard let account = getAccount(xpub: xpub) else {
            return
        }
        if let wm = WalletsRepository.shared.get(for: account), wm.logged {
            AccountNavigator.goLogged(accountId: account.id)
        } else {
            AccountNavigator.goLogin(accountId: account.id)
        }
         ()
    }

    // Delivers a notification to an app running in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([])
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
