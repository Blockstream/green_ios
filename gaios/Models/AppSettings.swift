import Foundation

struct AppSettings: Codable {

    static var shared = AppSettings()
    static let testnetIsVisible = "testnet_is_visible"
    static let experimental = "experimental"
    static let rememberHWIsOff = "remember_HW_is_off"
    
    var testnet: Bool {
        get { UserDefaults.standard.bool(forKey: AppSettings.testnetIsVisible) == true }
        set { UserDefaults.standard.set(newValue, forKey: AppSettings.testnetIsVisible) }
    }

    var experimental: Bool {
        get { UserDefaults.standard.bool(forKey: AppSettings.experimental) == true }
        set { UserDefaults.standard.set(newValue, forKey: AppSettings.experimental) }
    }

    var rememberHWIsOff: Bool {
        get { UserDefaults.standard.bool(forKey: AppSettings.rememberHWIsOff) == true }
        set { UserDefaults.standard.set(newValue, forKey: AppSettings.rememberHWIsOff) }
    }
    
    var gdkSettings: GdkSettings? {
        get { GdkSettings.read() }
        set { newValue?.write() }
    }

    func write() {
        let newValue = self.toDict()
        UserDefaults.standard.set(newValue, forKey: "network_settings")
        UserDefaults.standard.synchronize()
    }
}
