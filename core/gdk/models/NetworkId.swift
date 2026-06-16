import Foundation

public enum NetworkId: String, Codable, CaseIterable {
    case greenMainnet = "mainnet"
    case electrumMainnet = "electrum-mainnet"
    case greenLiquid = "liquid"
    case electrumLiquid = "electrum-liquid"
    case greenTestnet = "testnet"
    case electrumTestnet = "electrum-testnet"
    case greenTestnetLiquid = "testnet-liquid"
    case electrumTestnetLiquid = "electrum-testnet-liquid"

    case lightningMainnet = "greenlight-mainnet"
    case lwkMainnet = "lwk-mainnet"

    public init?(network: String) {
        self.init(rawValue: network)
    }

    public var network: String {
        self.rawValue
    }

    public var gdkNetwork: GdkNetwork {
        return Gdk.shared.networks.getNetworkBy(self)
    }

    public var chain: String {
        network.replacingOccurrences(of: "electrum-", with: "")
            .replacingOccurrences(of: "greenlight-", with: "")
            .replacingOccurrences(of: "lwk-", with: "")
    }

    public var singlesig: Bool { gdkNetwork.singlesig }
    public var multisig: Bool { gdkNetwork.multisig }
    public var lightning: Bool { gdkNetwork.lightning }
    public var testnet: Bool { !gdkNetwork.mainnet }
    public var liquid: Bool { gdkNetwork.liquid }
    public var bitcoin: Bool { !liquid && !lightning }

    public func name() -> String {
        switch self {
        case .greenMainnet:
            return "Multisig Bitcoin"
        case .electrumMainnet:
            return "Singlesig Bitcoin"
        case .greenLiquid:
            return "Multisig Liquid"
        case .electrumLiquid:
            return "Singlesig Liquid"
        case .greenTestnet:
            return "Multisig Testnet"
        case .electrumTestnet:
            return "Singlesig Testnet"
        case .greenTestnetLiquid:
            return "Multisig Liquid Testnet"
        case .electrumTestnetLiquid:
            return "Singlesig Liquid Testnet"
        case .lightningMainnet:
            return "Lightning"
        case .lwkMainnet:
            return "Liquid Swaps"
        }
    }
}
