import Foundation

public struct AppSettings: Codable {

    public static var shared = AppSettings()
    public static let testnetIsVisible = "testnet_is_visible"
    public static let experimental = "experimental"
    public static let rememberHWIsOff = "remember_HW_is_off"

    public var testnet: Bool {
        get { UserDefaults.standard.bool(forKey: AppSettings.testnetIsVisible) == true }
        set { UserDefaults.standard.set(newValue, forKey: AppSettings.testnetIsVisible) }
    }

    public var experimental: Bool {
        get { UserDefaults.standard.bool(forKey: AppSettings.experimental) == true }
        set { UserDefaults.standard.set(newValue, forKey: AppSettings.experimental) }
    }

    var rememberHWIsOff: Bool {
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
