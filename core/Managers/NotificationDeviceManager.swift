import Foundation
import os.log

struct RegisterDeviceRequest: Codable {
    let externalCustomerId: String
    let fcmToken: String
    let platform: String
    let nodeId: String?
}

struct RegisterDeviceResponse: Codable {
    let status: String
    let message: String
}

enum CallMethod: String {
    case post = "POST"
}

public class NotificationDeviceManager {
    public static let shared = NotificationDeviceManager()
    
    static let NOTIFICATIONS_URL_PRODUCTION = "https://green-webhooks.blockstream.com"
    static let NOTIFICATIONS_URL_DEVELOPMENT = "https://green-webhooks.dev.blockstream.com"
    
    private var notificationBaseUrl: String {
        Bundle.main.dev ? NotificationDeviceManager.NOTIFICATIONS_URL_DEVELOPMENT : NotificationDeviceManager.NOTIFICATIONS_URL_PRODUCTION
    }
    
    private init() {}
    
    static func call<T: Codable, K: Codable>(url: URL, method: CallMethod, params: T) async throws -> K {
        let encodedData = try params.encoded()
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpMethod = method.rawValue
        if method == .post {
            request.httpBody = encodedData
        }
        request.timeoutInterval = 10
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(K.self, from: data)
    }
    
    public func registerDevice(walletHashedId: String, fcmToken: String, nodeId: String? = nil) async throws {
        logger.info("Register device token \(fcmToken) for \(walletHashedId) on \(self.notificationBaseUrl) with nodeId: \(nodeId ?? "")")
        if let baseUrl = URL(string: notificationBaseUrl) {
            let url = baseUrl.appending(path: "register-device")
            let finalNodeId = Bundle.main.dev ? nodeId : nil
            let params = RegisterDeviceRequest(externalCustomerId: walletHashedId, fcmToken: fcmToken, platform: "ios", nodeId: finalNodeId)
            let _: RegisterDeviceResponse = try await NotificationDeviceManager.call(url: url, method: .post, params: params)
        }
    }
}
