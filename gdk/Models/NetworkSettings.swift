import Foundation

public struct NetworkSettings: Codable {

    enum CodingKeys: String, CodingKey {
        case name
        case useTor = "use_tor"
        case proxy
        case userAgent = "user_agent"
        case spvEnabled = "spv_enabled"
        case electrumUrl = "electrum_url"
        case electrumOnionUrl = "electrum_onion_url"
    }

    public let name: String
    public let useTor: Bool?
    public let proxy: String?
    public let userAgent: String?
    public let spvEnabled: Bool?
    public let electrumUrl: String?
    public let electrumOnionUrl: String?

    public init(
        name: String,
        useTor: Bool? = nil,
        proxy: String? = nil,
        userAgent: String? = nil,
        spvEnabled: Bool? = nil,
        electrumUrl: String? = nil,
        electrumOnionUrl: String? = nil) {
        self.name = name
        self.useTor = useTor
        self.proxy = proxy
        self.userAgent = userAgent
        self.spvEnabled = spvEnabled
        self.electrumUrl = electrumUrl
        self.electrumOnionUrl = electrumOnionUrl
    }
}
