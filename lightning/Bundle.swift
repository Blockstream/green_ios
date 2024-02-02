import Foundation

extension Bundle {

    public var breezApiKey: String? {
        guard let content = Bundle.main.infoDictionary?["BREEZ_API_KEY"] as? String,
              !content.isEmpty else {
            fatalError("breez Api Key: not found")
        }
        return content
    }

    public var greenlightDeviceCert: Data? {
        if let filePath = Bundle.main.path(forResource: "greenlight_device_cert", ofType: "txt"),
            var content = FileManager.default.contents(atPath: filePath),
            !content.isEmpty {
            content.removeLast()
            return Data(base64Encoded: content)
        }
        fatalError("greenlight device cert: not found")
    }

    public var greenlightDeviceKey: Data? {
        if let filePath = Bundle.main.path(forResource: "greenlight_device_key", ofType: "txt"),
            var content = FileManager.default.contents(atPath: filePath),
            !content.isEmpty {
            content.removeLast()
            return Data(base64Encoded: content)
        }
        fatalError("greenlight device key: not found")
    }
}
