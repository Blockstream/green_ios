extension WalletManager {

    // Get Network Id

    public var bitcoinSinglesigNetworkId: NetworkId {
        mainnet ? .electrumMainnet : .electrumTestnet
    }
    public var liquidSinglesigNetworkId: NetworkId {
        mainnet ? .electrumLiquid : .electrumTestnetLiquid
    }
    public var lwkNetworkId: NetworkId {
        mainnet ? .lwkMainnet : .lwkTestnet
    }
    public var singlesigNetworkIds: [NetworkId] { [bitcoinSinglesigNetworkId] + [liquidSinglesigNetworkId] }
    public var bitcoinMultisigNetworkId: NetworkId {
        mainnet ? .greenMainnet : .greenTestnet
    }
    public var liquidMultisigNetworkId: NetworkId {
        mainnet ? .greenLiquid : .greenTestnetLiquid
    }
    public var multisigNetworkIds: [NetworkId] { [bitcoinMultisigNetworkId] + [liquidMultisigNetworkId] }
    public var bitcoinNetworkIds: [NetworkId] { [bitcoinSinglesigNetworkId] + [bitcoinMultisigNetworkId] }
    public var liquidNetworkIds: [NetworkId] { [liquidSinglesigNetworkId] + [liquidMultisigNetworkId] + [lwkNetworkId]}


    // Active networks Id
    public var activeLiquidNetworkIds: [NetworkId] {
        activeLiquidBackends.map { $0.networkId }
    }
    public var activeGdkLiquidNetworkIds: [NetworkId] {
        activeGdkLiquidBackends.map { $0.networkId }
    }
    public var activeBitcoinNetworkIds: [NetworkId] {
        activeBitcoinBackends.map { $0.networkId }
    }
    public var activeGdkSinglesigNetworkIds: [NetworkId] {
        activeGdkSinglesigBackends.map { $0.networkId }
    }
    public var activeGdkMultisigNetworkIds: [NetworkId] {
        activeGdkMultisigBackends.map { $0.networkId }
    }

    public func hasActiveNetwork(_ network: GdkNetwork) -> Bool {
        hasActiveNetwork(network.networkId)
    }

    public func hasActiveNetwork(_ networkId: NetworkId) -> Bool {
        let backend = networkBackends[networkId] 
        return activeNetworkIds.contains(networkId) && backend?.isLoggedIn ?? false
    }


    public var activeNetworkIds: Set<NetworkId> {
        let pairs = networkBackends.compactMap { (key, value) -> NetworkId? in
            if value.isConnected { return key }
            return nil
        }
        return Set(pairs)
    }

}
