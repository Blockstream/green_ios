import Foundation
import BreezSDK

public struct AppGreenlightCredentials: Codable {

    let deviceKey: Data
    let deviceCert: Data

    public init(deviceKey: Data, deviceCert: Data) {
        self.deviceKey = deviceKey
        self.deviceCert = deviceCert
    }

    init(gc: GreenlightCredentials) {
        self.deviceKey = Data(gc.developerKey)
        self.deviceCert = Data(gc.developerCert)
    }

    var greenlightCredentials: GreenlightCredentials {
        GreenlightCredentials(developerKey: [UInt8](deviceKey),
                              developerCert: [UInt8](deviceCert))
    }
}
