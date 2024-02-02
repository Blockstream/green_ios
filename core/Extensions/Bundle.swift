import Foundation

extension Bundle {

    public var appName: String {
        return infoDictionary?["CFBundleName"] as? String ?? ""
    }

    public var bundleId: String {
        return bundleIdentifier!
    }

    public var versionNumber: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    public var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    public var dev: Bool {
        return bundleId == "io.blockstream.greendev"
    }

    public var appGroup: String {
        return infoDictionary?["APPGROUP"] as? String ?? ""
    }

    public var googleServiceInfo: String {
        infoDictionary?["GOOGLE_SERVICE_INFO"] as? String ?? ""
    }

    public var notificationService: String? {
        let url = infoDictionary?["NOTIFICATION_SERVICE"] as? String
        return url?.replacingOccurrences(of: "\\/\\/", with: "//")
    }
}
