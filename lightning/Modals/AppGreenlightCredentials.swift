import Foundation
import GreenlightSDK

public struct AppGreenlightCredentials: Codable {

    let deviceKey: Data
    let deviceCert: Data

    public init(deviceKey: Data, deviceCert: Data) {
        self.deviceKey = deviceKey
        self.deviceCert = deviceCert
    }
    var cert: DeveloperCert {
        DeveloperCert(cert: deviceCert, key: deviceKey)
    }
}
