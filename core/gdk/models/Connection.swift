import Foundation

public struct Connection: Codable {
    enum CodingKeys: String, CodingKey {
        case currentState = "current_state"
        case nextState = "next_state"
        case waitMs = "wait_ms"
        case loginRequired = "login_required"
        case error = "error"
    }
    public let currentState: String
    public let nextState: String
    public let waitMs: UInt8 = 0
    public let loginRequired: Bool?
    public var error: String?
    public var connected: Bool {
        return currentState == "connected"
    }
}
