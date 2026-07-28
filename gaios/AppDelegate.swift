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

    var window: UIWindow?
    var navigateWindow: UIWindow?
    var resolve2faWindow: UIWindow?

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

    @MainActor
    func setupMainWindow(windowScene: UIWindowScene? = nil) {
        if let windowScene = windowScene {
            window = UIWindow(windowScene: windowScene)
        } else {
            window = makeWindow()
        }
        window?.endEditing(true)

        // Set screen lock
        ScreenLockWindow.shared.setup(windowScene: window?.windowScene)

        // Open first page
        WalletNavigator.navFirstPage()
        window?.makeKeyAndVisible()
    }

    func makeWindow() -> UIWindow {
        if let windowScene = window?.windowScene ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) {
            return UIWindow(windowScene: windowScene)
        }
        return UIWindow(frame: UIScreen.main.bounds)
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

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        handleWillResignActive()
    }

    func handleWillResignActive() {
        resolve2faWindow?.isHidden = true
        ScreenLocker.shared.applicationWillResignActive()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        handleDidEnterBackground()
    }

    func handleDidEnterBackground() {
        ScreenLocker.shared.applicationDidEnterBackground()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        handleWillEnterForeground()
    }

    func handleWillEnterForeground() {
        ScreenLocker.shared.applicationWillEnterForeground()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

        handleDidBecomeActive()
    }

    func handleDidBecomeActive() {

        ScreenLocker.shared.applicationDidBecomeActive()
        Loader.resume()

        if let resolve2faWindow = resolve2faWindow {
            resolve2faWindow.isHidden = false
            resolve2faWindow.makeKeyAndVisible()
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

    func resolve2faOn(_ vc: UIViewController) {
        resolve2faWindow = makeWindow()
        resolve2faWindow!.windowLevel = UIWindow.Level.alert
        vc.view.frame = resolve2faWindow!.bounds
        resolve2faWindow!.rootViewController = vc
        resolve2faWindow!.makeKeyAndVisible()
    }

    func resolve2faOff() {
        resolve2faWindow?.removeFromSuperview()
        resolve2faWindow = nil
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        AppNotifications.shared.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken: deviceToken)
    }
}
