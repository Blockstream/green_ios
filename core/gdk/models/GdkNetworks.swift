import Foundation

import greenaddress

public class GdkNetworks: Codable {

    private enum CodingKeys: String, CodingKey {
        case greenMainnet = "mainnet"
        case electrumMainnet = "electrum-mainnet"
        case greenLiquid = "liquid"
        case electrumLiquid = "electrum-liquid"
        case greenTestnet = "testnet"
        case electrumTestnet = "electrum-testnet"
        case greenTestnetLiquid = "testnet-liquid"
        case electrumTestnetLiquid = "electrum-testnet-liquid"
    }
    public let greenMainnet: GdkNetwork
    public let electrumMainnet: GdkNetwork
    public let greenLiquid: GdkNetwork
    public let electrumLiquid: GdkNetwork
    public let greenTestnet: GdkNetwork
    public let electrumTestnet: GdkNetwork
    public let greenTestnetLiquid: GdkNetwork
    public let electrumTestnetLiquid: GdkNetwork

    public lazy var lightningMainnet = GdkNetwork(
        name: NetworkId.lightningMainnet.name(),
        network: NetworkId.lightningMainnet.network,
        liquid: false,
        mainnet: true,
        development: false,
        txExplorerUrl: electrumMainnet.txExplorerUrl,
        policyAsset: AssetInfo.lightningId,
        serverType: "greenlight",
        bip21Prefix: "lightning")

    public lazy var lwkMainnet = GdkNetwork(
        name: NetworkId.lwkMainnet.name(),
        network: NetworkId.lwkMainnet.network,
        liquid: true,
        mainnet: true,
        development: false,
        txExplorerUrl: electrumLiquid.txExplorerUrl,
        policyAsset: electrumLiquid.getFeeAsset(),
        serverType: "electrum",
        bip21Prefix: electrumLiquid.bip21Prefix)

    public lazy var lwkSwapMainnet = GdkNetwork(
        name: NetworkId.lwkSwapMainnet.name(),
        network: NetworkId.lwkSwapMainnet.network,
        liquid: true,
        mainnet: true,
        development: false,
        txExplorerUrl: electrumLiquid.txExplorerUrl,
        policyAsset: electrumLiquid.getFeeAsset(),
        serverType: "electrum" )

    public lazy var lwkTestnet = GdkNetwork(
        name: NetworkId.lwkTestnet.name(),
        network: NetworkId.lwkTestnet.network,
        liquid: true,
        mainnet: false,
        development: false,
        txExplorerUrl: electrumTestnetLiquid.txExplorerUrl,
        policyAsset: electrumTestnetLiquid.getFeeAsset(),
        serverType: "electrum",
        bip21Prefix: electrumTestnetLiquid.bip21Prefix                                  )

    public func getNetworkBy(_ id: NetworkId) -> GdkNetwork {
        switch id {
        case .lightningMainnet:
            return lightningMainnet
        case .lwkMainnet:
            return lwkMainnet
        case .lwkTestnet:
            return lwkTestnet
        case .greenMainnet:
            return greenMainnet
        case .electrumMainnet:
            return electrumMainnet
        case .greenLiquid:
            return greenLiquid
        case .electrumLiquid:
            return electrumLiquid
        case .greenTestnet:
            return greenTestnet
        case .electrumTestnet:
            return electrumTestnet
        case .greenTestnetLiquid:
            return greenTestnetLiquid
        case .electrumTestnetLiquid:
            return electrumTestnetLiquid
        case .lwkSwapMainnet:
            return lwkSwapMainnet
        }
    }
}
