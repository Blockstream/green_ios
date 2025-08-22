import greenaddress
import gdk

extension Wally {
    public static func getWallyNetwork(_ network: NetworkSecurityCase) -> UInt32 {
        switch network {
        case .bitcoinSS, .bitcoinMS:
            return Wally.WALLY_NETWORK_BITCOIN_MAINNET
        case .testnetSS, .testnetMS:
            return Wally.WALLY_NETWORK_BITCOIN_TESTNET
        case .liquidSS, .liquidMS:
            return Wally.WALLY_NETWORK_LIQUID
        case .testnetLiquidSS, .testnetLiquidMS:
            return Wally.WALLY_NETWORK_LIQUID_TESTNET
        default:
            return Wally.WALLY_NETWORK_BITCOIN_MAINNET
        }
    }

    public static func isDescriptor(_ desc: String, for network: NetworkSecurityCase) -> Bool {
        if Wally.descriptorParse(desc, network: getWallyNetwork(network)) != nil {
            return true
        }
        return false
    }

    public static func isPubKey(_ xpub: String, for network: NetworkSecurityCase) -> Bool {
        if network.bitcoin && !network.testnet && ["xpub", "ypub", "zpub"].contains(xpub.prefix(4).lowercased()) {
            return true
        } else if network.bitcoin && network.testnet && ["tpub", "upub", "vpub"].contains(xpub.prefix(4).lowercased()) {
            return true
        }
        return false
    }

    public static func getNetwork(descriptor: String) -> NetworkSecurityCase? {
        let networks: [NetworkSecurityCase] = descriptor.starts(with: "ct") ? [.liquidSS, .testnetLiquidSS] : [.bitcoinSS, .testnetSS]
        for network in networks {
            if Wally.descriptorParse(descriptor, network: getWallyNetwork(network)) != nil {
                return network
            }
        }
        return nil
    }

    public static func getNetwork(xpub: String) -> NetworkSecurityCase? {
        if ["xpub", "ypub", "zpub"].contains(xpub.prefix(4).lowercased()) {
            return .bitcoinSS
        } else if ["tpub", "upub", "vpub"].contains(xpub.prefix(4).lowercased()) {
            return .testnetSS
        }
        return nil
    }
}
