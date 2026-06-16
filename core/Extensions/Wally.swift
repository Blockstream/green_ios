import greenaddress


extension Wally {
    public static func getWallyNetwork(_ network: NetworkId) -> UInt32 {
        switch network {
        case .electrumMainnet, .greenMainnet:
            return Wally.WALLY_NETWORK_BITCOIN_MAINNET
        case .electrumTestnet, .greenTestnet:
            return Wally.WALLY_NETWORK_BITCOIN_TESTNET
        case .electrumLiquid, .greenLiquid:
            return Wally.WALLY_NETWORK_LIQUID
        case .electrumTestnetLiquid, .greenTestnetLiquid:
            return Wally.WALLY_NETWORK_LIQUID_TESTNET
        default:
            return Wally.WALLY_NETWORK_BITCOIN_MAINNET
        }
    }

    public static func isDescriptor(_ desc: String, for network: NetworkId) -> Bool {
        return getNetwork(descriptor: desc) == network
    }

    public static func isPubKey(_ xpub: String, for network: NetworkId) -> Bool {
        return getNetwork(xpub: xpub) == network
    }

    public static func getNetwork(descriptor: String) -> NetworkId? {
        let networks: [NetworkId] = descriptor.starts(with: "ct") ? [.electrumLiquid, .electrumTestnetLiquid] : [.electrumMainnet, .electrumTestnet]
        for network in networks {
            if Wally.descriptorParse(descriptor, network: getWallyNetwork(network)) != nil {
                return network
            }
        }
        return nil
    }

    public static func getNetwork(xpub: String) -> NetworkId? {
        if ["xpub", "ypub", "zpub"].contains(xpub.prefix(4).lowercased()) {
            return .electrumMainnet
        } else if ["tpub", "upub", "vpub"].contains(xpub.prefix(4).lowercased()) {
            return .electrumTestnet
        }
        return nil
    }
}
