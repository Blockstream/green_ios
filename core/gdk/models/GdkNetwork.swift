import Foundation
import greenaddress

public struct GdkNetwork: Codable, Equatable, Comparable, Sendable {

    enum CodingKeys: String, CodingKey {
        case name
        case network
        case liquid
        case development
        case txExplorerUrl = "tx_explorer_url"
        case icon
        case mainnet
        case policyAsset = "policy_asset"
        case serverType = "server_type"
        case csvBuckets = "csv_buckets"
        case bip21Prefix = "bip21_prefix"
        case electrumUrl = "electrum_url"
        case electrumOnionUrl = "electrum_onion_url"
    }

    public let name: String
    public let network: String
    public let liquid: Bool
    public let mainnet: Bool
    public let development: Bool
    public let txExplorerUrl: String?
    public var icon: String?
    public var policyAsset: String?
    public var serverType: String?
    public var csvBuckets: [Int]?
    public var bip21Prefix: String?
    public var electrumUrl: String?
    public var electrumOnionUrl: String?

    // Get the asset used to pay transaction fees
    public func getFeeAsset() -> String {
        return self.policyAsset ?? AssetInfo.btcId
    }
    public func getFeeAssetOrNull() -> String? {
        return self.policyAsset
    }

    public var electrum: Bool {
        "electrum" == serverType
    }

    public var lightning: Bool {
        "greenlight" == serverType
    }

    public var testnet: Bool {
        !mainnet
    }

    public var singlesig: Bool {
        electrum
    }

    public var multisig: Bool {
        "green" == serverType
    }
    public var bitcoin: Bool {
        return !liquid && !lightning
    }
    public var bitcoinOrLightning: Bool {
        return !liquid
    }

    public var bitcoinMainnet: Bool {
        return networkId == .greenMainnet || networkId == .electrumMainnet
    }

    public var liquidMainnet: Bool {
        return networkId == .greenLiquid || networkId == .electrumLiquid
    }

    public var bitcoinTestnet: Bool {
        return networkId == .greenTestnet || networkId == .electrumTestnet
    }

    public var liquidTestnet: Bool {
        return networkId == .greenTestnetLiquid || networkId == .electrumTestnetLiquid
    }
    public var networkId: NetworkId {
        NetworkId(rawValue: network)!
    }

    public var chain: String {
        network.replacingOccurrences(of: "electrum-", with: "")
            .replacingOccurrences(of: "lightning-", with: "")
            .replacingOccurrences(of: "lwk-", with: "")
            .replacingOccurrences(of: "lwkswap-", with: "")
    }

    public var defaultFee: UInt64 {
        liquid ? 100 : 1000
    }

    var blocksPerHour: Int {
        return liquid ? 60 : 6
    }

    var confirmationsRequired: Int64 {
        if lightning { return 1 }
        if liquid { return 2 }
        return 6
    }

    var zendeskValue: String {
        if singlesig { return "singlesig__green_" }
        if multisig { return "multisig_shield__green_" }
        if lightning { return "lightning__green_" }
        return ""
    }

    func isSameNetwork(other: GdkNetwork) -> Bool {
        return (bitcoin && other.bitcoin) || (lightning && other.lightning) || (liquid && other.liquid)
    }

    var canonicalName: String {
        switch networkId {
        case NetworkId.greenMainnet, NetworkId.electrumMainnet:
            return "Bitcoin"
        case NetworkId.greenTestnet, NetworkId.electrumTestnet:
            return "Testnet"
        case NetworkId.greenLiquid, NetworkId.electrumLiquid:
            return "Liquid"
        case NetworkId.greenTestnetLiquid, NetworkId.electrumTestnetLiquid:
            return "Testnet Liquid"
        default:
            return name
        }
    }

    var productName: String {
        if electrum {
            return "Singlesig \(canonicalName)"
        } else {
            return "Multisig \(canonicalName)"
        }
    }

    var explorerUrl: String? {
        txExplorerUrl?.replacingOccurrences(of: "tx/", with: "")
    }

    public static func < (lhs: GdkNetwork, rhs: GdkNetwork) -> Bool {
        let rules: [NetworkId] = [
            .electrumMainnet,
            .electrumTestnet,
            .greenMainnet,
            .greenTestnet,
            .lightningMainnet,
            .electrumLiquid,
            .electrumTestnetLiquid,
            .greenLiquid,
            .greenTestnetLiquid
        ]
        let lnet = NetworkId(rawValue: lhs.network) ?? .electrumMainnet
        let rnet = NetworkId(rawValue: rhs.network) ?? .electrumMainnet
        return rules.firstIndex(of: lnet) ?? 0 < rules.firstIndex(of: rnet) ?? 0
    }
}
