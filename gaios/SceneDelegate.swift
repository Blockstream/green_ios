import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene,
              let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        setupMainWindow(windowScene: windowScene)

        if let urlContext = connectionOptions.urlContexts.first {
            appDelegate.handleOpen(url: urlContext.url, sourceApplication: urlContext.options.sourceApplication)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let urlContext = URLContexts.first,
              let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        appDelegate.handleOpen(url: urlContext.url, sourceApplication: urlContext.options.sourceApplication)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        handleWillResignActive()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        handleDidEnterBackground()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        handleWillEnterForeground()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        handleDidBecomeActive()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        window = nil
    }

    @MainActor
    private func setupMainWindow(windowScene: UIWindowScene) {
        window = UIWindow(windowScene: windowScene)
        window?.endEditing(true)

        // Set screen lock
        ScreenLockWindow.shared.setup(windowScene: windowScene)

        // Make the scene window discoverable
        window?.makeKeyAndVisible()

        // Open first page
        WalletNavigator.navFirstPage()
    }

    private func handleWillResignActive() {
        getAppDelegate()?.resolve2faWindow?.isHidden = true
        ScreenLocker.shared.applicationWillResignActive()
    }

    private func handleDidEnterBackground() {
        ScreenLocker.shared.applicationDidEnterBackground()
    }

    private func handleWillEnterForeground() {
        ScreenLocker.shared.applicationWillEnterForeground()
    }

    private func handleDidBecomeActive() {
        ScreenLocker.shared.applicationDidBecomeActive()
        Loader.resume()

        if let resolve2faWindow = getAppDelegate()?.resolve2faWindow {
            resolve2faWindow.isHidden = false
            resolve2faWindow.makeKeyAndVisible()
        }
    }
}
