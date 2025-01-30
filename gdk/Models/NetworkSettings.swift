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
        case electrumTls = "electrum_tls"
        case gapLimit = "gap_limit"
        case discountFees = "discount_fees"
    }

    public let name: String
    public let useTor: Bool?
    public let proxy: String?
    public let userAgent: String?
    public let spvEnabled: Bool?
    public let electrumUrl: String?
    public let electrumOnionUrl: String?
    public let electrumTls: Bool?
    public let gapLimit: Int?
    public let discountFees: Bool?

    public init(
        name: String,
        useTor: Bool? = nil,
        proxy: String? = nil,
        userAgent: String? = nil,
        spvEnabled: Bool? = nil,
        electrumUrl: String? = nil,
        electrumOnionUrl: String? = nil,
        electrumTls: Bool? = nil,
        gapLimit: Int? = nil,
        discountFees: Bool? = nil) {
        self.name = name
        self.useTor = useTor
        self.proxy = proxy
        self.userAgent = userAgent
        self.spvEnabled = spvEnabled
        self.electrumUrl = electrumUrl
        self.electrumOnionUrl = electrumOnionUrl
        self.electrumTls = electrumTls
        self.gapLimit = gapLimit
        self.discountFees = discountFees
    }
}
