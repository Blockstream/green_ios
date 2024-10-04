import Foundation

public struct AppSettings: Codable {

    public static var shared = AppSettings()
    static let testnetIsVisible = "testnet_is_visible"
    static let experimental = "experimental"
    static let useTrampoline = "use_trampoline"
    static let rememberHWIsOff = "remember_HW_is_off"

    public var testnet: Bool {
        get { UserDefaults.standard.bool(forKey: AppSettings.testnetIsVisible) == true }
        set { UserDefaults.standard.set(newValue, forKey: AppSettings.testnetIsVisible) }
    }

    public var experimental: Bool {
        get { UserDefaults.standard.bool(forKey: AppSettings.experimental) == true }
        set { UserDefaults.standard.set(newValue, forKey: AppSettings.experimental) }
    }
    public var useTrampoline: Bool {
        get { UserDefaults.standard.bool(forKey: AppSettings.useTrampoline) == true }
        set { UserDefaults.standard.set(newValue, forKey: AppSettings.useTrampoline) }
    }

    public var rememberHWIsOff: Bool {
        get { UserDefaults.standard.bool(forKey: AppSettings.rememberHWIsOff) == true }
        set { UserDefaults.standard.set(newValue, forKey: AppSettings.rememberHWIsOff) }
    }

    public var gdkSettings: GdkSettings? {
        get { GdkSettings.read() }
        set { newValue?.write() }
    }

    public func write() {
        let newValue = self.toDict()
        UserDefaults.standard.set(newValue, forKey: "network_settings")
        UserDefaults.standard.synchronize()
    }
}
