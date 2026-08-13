import UIKit

import UserNotifications
import core
import AVFoundation
import FirebaseMessaging

func getAppDelegate() -> AppDelegate? {
    return UIApplication.shared.delegate as? AppDelegate
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    func setupAppearance() {
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.backgroundColor = UIColor.gBlackBg()
            appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
            appearance.shadowImage = UIImage.imageWithColor(color: UIColor.gBlackBg())
            appearance.backgroundImage = UIImage()
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().isTranslucent = false
        }
        UINavigationBar.appearance().barTintColor = UIColor.gBlackBg()
        UINavigationBar.appearance().tintColor = UIColor.white
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        UINavigationBar.appearance().isTranslucent = false
        UITextField.appearance().keyboardAppearance = .dark
        UITextField.appearance().tintColor = UIColor.white
        // To hide the bottom line of the navigation bar.
        UINavigationBar.appearance().setBackgroundImage(UIImage(), for: .any, barMetrics: .default)
        UINavigationBar.appearance().shadowImage = UIImage()
        // Hide the top line of the tab bar
        UITabBar.appearance().shadowImage = UIImage()
        UITabBar.appearance().backgroundImage = UIImage()
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // register notifications
        UNUserNotificationCenter.current().delegate = AppNotifications.shared
        AppNotifications.shared.registerForFcmPushNotifications()

        // Override point for customization after application launch.
        setupAppearance()

        #if targetEnvironment(simulator)
        // Disable hardware keyboards.
        let setHardwareLayout = NSSelectorFromString("setHardwareLayout:")
        UITextInputMode.activeInputModes
            .filter({ $0.responds(to: setHardwareLayout) })
            .forEach { $0.perform(setHardwareLayout, with: nil) }
        #endif

        PromoManager.shared.start()

        // start analytics
        AnalyticsManager.shared.countlyStart()
        AnalyticsManager.shared.setupSession(session: nil)

        // run account migration
        MigratorManager.shared.migrate()

        #if DEBUG
        // parse externally injected wallet
        WalletsStorage.shared.injectWalletFromEnvironment()
        #endif

        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        handleOpen(url: url, sourceApplication: options[.sourceApplication] as? String)

        return true
    }

    func handleOpen(url: URL, sourceApplication: String?) {
        URLSchemeManager.shared.sendingAppID = sourceApplication
        URLSchemeManager.shared.url = url
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
            DropAlert().info(message: "id_you_have_clicked_a_uri_select_a".localized)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: EventType.bip21Scheme.rawValue),
                                                object: nil, userInfo: nil)
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        Task.detached { [weak self] in await self?.disconnect() }
    }

    func disconnect() async {
        for wm in WalletsRepository.shared.wallets.values where wm.logged {
            await wm.disconnect()
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        AppNotifications.shared.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken: deviceToken)
    }
}
