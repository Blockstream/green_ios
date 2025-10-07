import Foundation

import greenaddress

public struct GdkNetwork: Codable, Equatable, Comparable {

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
        "breez" == serverType
    }

    public var singlesig: Bool {
        electrum
    }

    public var multisig: Bool {
        !electrum && !lightning
    }

    public var chain: String {
        network.replacingOccurrences(of: "electrum-", with: "")
            .replacingOccurrences(of: "lightning-", with: "")
    }

    public var defaultFee: UInt64 {
        liquid ? 100 : 1000
    }

    public static func < (lhs: GdkNetwork, rhs: GdkNetwork) -> Bool {
        let rules: [NetworkSecurityCase] = [.bitcoinSS, .testnetSS, .bitcoinMS, .testnetMS, .lightning, .liquidSS, .testnetLiquidSS, .liquidMS, .testnetLiquidMS]
        let lnet = NetworkSecurityCase(rawValue: lhs.network) ?? .bitcoinSS
        let rnet = NetworkSecurityCase(rawValue: rhs.network) ?? .bitcoinSS
        return rules.firstIndex(of: lnet) ?? 0 < rules.firstIndex(of: rnet) ?? 0
    }
}

public struct GdkNetworks {

    public static var bitcoinSS = getGdkNetwork(NetworkSecurityCase.bitcoinSS.network)
    public static var bitcoinMS = getGdkNetwork(NetworkSecurityCase.bitcoinMS.network)
    public static var testnetSS = getGdkNetwork(NetworkSecurityCase.testnetSS.network)
    public static var testnetMS = getGdkNetwork(NetworkSecurityCase.testnetMS.network)
    public static var liquidSS = getGdkNetwork(NetworkSecurityCase.liquidSS.network)
    public static var liquidMS = getGdkNetwork(NetworkSecurityCase.liquidMS.network)
    public static var testnetLiquidSS = getGdkNetwork(NetworkSecurityCase.testnetLiquidSS.network)
    public static var testnetLiquidMS = getGdkNetwork(NetworkSecurityCase.testnetLiquidMS.network)

    public static var lwkMainnet = GdkNetwork(name: NetworkSecurityCase.lwkMainnet.name(),
                                           network: NetworkSecurityCase.liquidSS.network,
                                           liquid: true,
                                           mainnet: false,
                                           development: false,
                                     txExplorerUrl: GdkNetworks.liquidSS.txExplorerUrl,
                                     policyAsset: GdkNetworks.liquidSS.getFeeAsset())
    public static var lightning = GdkNetwork(name: NetworkSecurityCase.lightning.name(),
                                           network: NetworkSecurityCase.lightning.network,
                                           liquid: false,
                                           mainnet: true,
                                           development: false,
                                           txExplorerUrl: GdkNetworks.bitcoinSS.txExplorerUrl,
                                           policyAsset: AssetInfo.lightningId,
                                           serverType: "breez")
    public static var testnetLightning = GdkNetwork(name: NetworkSecurityCase.testnetLightning.name(),
                                                  network: NetworkSecurityCase.testnetLightning.network,
                                                  liquid: false,
                                                  mainnet: false,
                                                  development: false,
                                             txExplorerUrl: GdkNetworks.testnetSS.txExplorerUrl,
                                                  policyAsset: AssetInfo.lightningId,
                                                  serverType: "breez")

    public static func get(networkType: NetworkSecurityCase) -> GdkNetwork {
        switch networkType {
        case .bitcoinSS: return GdkNetworks.bitcoinSS
        case .bitcoinMS: return GdkNetworks.bitcoinMS
        case .testnetSS: return GdkNetworks.testnetSS
        case .testnetMS: return GdkNetworks.testnetMS
        case .liquidSS: return GdkNetworks.liquidSS
        case .liquidMS: return GdkNetworks.liquidMS
        case .testnetLiquidSS: return GdkNetworks.testnetLiquidSS
        case .testnetLiquidMS: return GdkNetworks.testnetLiquidMS
        case .lightning: return GdkNetworks.lightning
        case .testnetLightning: return GdkNetworks.testnetLightning
        case .lwkMainnet: return GdkNetworks.lwkMainnet
        }
    }

    public static func get(network: String) -> GdkNetwork {
        if network == NetworkSecurityCase.lightning.network {
            return GdkNetworks.lightning
        } else if network == NetworkSecurityCase.lwkMainnet.network {
            return GdkNetworks.lwkMainnet
        } else if network == NetworkSecurityCase.testnetLightning.network {
            return GdkNetworks.testnetLightning
        } else {
            return GdkNetworks.getGdkNetwork(network)
        }
    }

    private static var cachedNetworks: [String: Any]?
    private static func getGdkNetwork(_ network: String, data: [String: Any]? = nil) -> GdkNetwork {
        if data ?? GdkNetworks.cachedNetworks == nil {
            GdkNetworks.cachedNetworks = try? getNetworks()
        }
        guard let res = data ?? GdkNetworks.cachedNetworks,
              let net = res[network] as? [String: Any],
              let jsonData = try? JSONSerialization.data(withJSONObject: net),
              var network = try? JSONDecoder().decode(GdkNetwork.self, from: jsonData)
        else {
            fatalError("invalid network")
        }
        network.icon = network.network.lowercased() == "mainnet" ? "ntw_btc" : "ntw_testnet"
        network.icon = network.liquid ? "ntw_liquid" : network.icon
        return network
    }
}
