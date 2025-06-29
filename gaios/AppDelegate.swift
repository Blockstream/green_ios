import UIKit
import gdk
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
        // Override point for customization after application launch.
        setupAppearance()

        // Load custom window to handle touches event
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.endEditing(true)

        // Initialize gdk
        GdkInit.defaults().run()

        // Set screen lock
        ScreenLockWindow.shared.setup()

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

        // register notifications
        UNUserNotificationCenter.current().delegate = AppNotifications.shared
        AppNotifications.shared.registerForFcmPushNotifications()

        // run account migration
        MigratorManager.shared.migrate()
        
        // Open first page
        AccountNavigator.navFirstPage()

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        URLSchemeManager.shared.sendingAppID = options[.sourceApplication] as? String
        URLSchemeManager.shared.url = url
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
            DropAlert().info(message: "id_you_have_clicked_a_uri_select_a".localized)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: EventType.bip21Scheme.rawValue),
                                                object: nil, userInfo: nil)
        }

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        resolve2faWindow?.isHidden = true
        ScreenLocker.shared.applicationWillResignActive()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        ScreenLocker.shared.applicationDidEnterBackground()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        ScreenLocker.shared.applicationWillEnterForeground()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

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
        for wm in WalletsRepository.shared.wallets.values {
            if wm.logged {
                await wm.disconnect()
            }
        }
    }

    func resolve2faOn(_ vc: UIViewController) {
        resolve2faWindow = UIWindow(frame: UIScreen.main.bounds)
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
        AppNotifications.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }
}
