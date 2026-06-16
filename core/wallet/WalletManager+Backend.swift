import greenaddress

extension WalletManager {

    // Get Network Backend

    public func networkBackend(_ network: NetworkId) throws -> NetworkBackend {
        guard let backend = networkBackends[network] else {
            throw GaError.GenericError("Invalid network backend for \(network.network)")
        }
        return backend
    }
    public func networkBackendOrNil(_ network: NetworkId) -> NetworkBackend? {
        try? networkBackend(network)
    }

    public func gdkNetworkBackend(_ network: NetworkId) throws -> GdkNetworkBackend {
        guard let backend = try networkBackend(network) as? GdkNetworkBackend else {
            throw GaError.GenericError("Invalid gdk network backend for \(network.network)")
        }
        return backend
    }

    public func glNetworkBackend() throws -> GlNetworkBackend {
        guard let backend = try networkBackend(.lightningMainnet) as? GlNetworkBackend else {
            throw GaError.GenericError("Invalid gl network backend for \(NetworkId.lightningMainnet.network)")
        }
        return backend
    }

    public func lwkNetworkBackend(_ network: NetworkId) throws -> LwkNetworkBackend {
        guard let backend = try networkBackend(network) as? LwkNetworkBackend else {
            throw GaError.GenericError("Invalid lwk network backend for \(network.network)")
        }
        return backend
    }
    public func gdkNetworkBackendOrNil(_ network: NetworkId) -> GdkNetworkBackend? {
        try? gdkNetworkBackend(network)
    }
    public func glNetworkBackendOrNil() -> GlNetworkBackend? {
        try? glNetworkBackend()
    }
    public func lwkNetworkBackendOrNil(_ network: NetworkId) -> LwkNetworkBackend? {
        try? lwkNetworkBackend(network)
    }

    public var loggedInGdkNetworkBackends: [NetworkId: GdkNetworkBackend] {
        networkBackends
            .filter { ($0.value as? GdkNetworkBackend) != nil }
            .filter { $0.value.isLoggedIn }
            .reduce(into: [NetworkId: GdkNetworkBackend]()) { result, element in
                let network = element.key
                if let gdkNetworkBackend = gdkNetworkBackendOrNil(network) {
                    result[network] = gdkNetworkBackend
                }
            }
    }

    public var loggedInNetworkBackends: [NetworkId: NetworkBackend] {
        networkBackends
            .filter { $0.value.isLoggedIn }
    }

    public var connectedNetworkBackends: [NetworkId: NetworkBackend] {
        networkBackends.filter { $0.value.isConnected }
    }

    public var connectedGdkNetworkBackends: [NetworkId: GdkNetworkBackend] {
        networkBackends
            .filter { ($0.value as? GdkNetworkBackend) != nil }
            .filter { $0.value.isConnected }
            .reduce(into: [NetworkId: GdkNetworkBackend]()) { result, element in
                let network = element.key
                if let gdkNetworkBackend = gdkNetworkBackendOrNil(network) {
                    result[network] = gdkNetworkBackend
                }
            }
    }

    // Get Account Backend

    public func accountBackend(_ account: Account) throws -> AccountBackend {
        try networkBackend(account.networkId)
            .accountBackend(account)
    }
    public func gdkAccountBackend(_ account: Account) throws -> GdkAccountBackend {
        guard let accountBackend = try accountBackend(account) as? GdkAccountBackend else {
            throw GaError.GenericError("Invalid gdk account backend for \(account.networkId.network) \(account.pointer)")
        }
        return accountBackend
    }
    public func glAccountBackend(_ account: Account) throws -> GlAccountBackend {
        guard let accountBackend = try accountBackend(account) as? GlAccountBackend else {
            throw GaError.GenericError("Invalid gl account backend for \(account.networkId.network) \(account.pointer)")
        }
        return accountBackend
    }
    public func lwAccountBackend(_ account: Account) throws -> LwkAccountBackend {
        guard let accountBackend = try? accountBackend(account) as? LwkAccountBackend else {
            throw GaError.GenericError("Invalid lwk account backend for \(account.networkId.network) \(account.pointer)")
        }
        return accountBackend
    }
    public func accountBackendOrNil(_ account: Account) -> AccountBackend? {
        try? accountBackend(account)
    }
    public func gdkAccountBackendOrNil(_ account: Account) -> GdkAccountBackend? {
        try? gdkAccountBackend(account)
    }
    public func glAccountBackendOrNil(_ account: Account) -> GlAccountBackend? {
        try? glAccountBackend(account)
    }
    public func lwAccountBackendOrNil(_ account: Account) -> LwkAccountBackend? {
        try? lwAccountBackend(account)
    }

    // Active backends
    public var activeBitcoinBackends: [NetworkBackend] {
        bitcoinNetworkIds
            .compactMap { try? networkBackend($0)}
            .filter { $0.isLoggedIn }
    }
    public var activeLiquidBackends: [NetworkBackend] {
        liquidNetworkIds
            .compactMap { try? networkBackend($0)}
            .filter { $0.isLoggedIn }
    }
    public var activeGdkSinglesigBackends: [GdkNetworkBackend] {
        singlesigNetworkIds
            .compactMap { gdkNetworkBackendOrNil($0)}
            .filter { $0.isLoggedIn }
    }
    public var activeGdkMultisigBackends: [GdkNetworkBackend] {
        multisigNetworkIds
            .compactMap { gdkNetworkBackendOrNil($0)}
            .filter { $0.isLoggedIn }
    }
    public var activeNetworkBackends: [NetworkBackend] {
        networks()
            .compactMap { networkBackends[$0] }
            .filter { $0.isLoggedIn }
    }
    // Get Network Backend

    public var liquidSinglesigBackend: GdkNetworkBackend? {
        gdkNetworkBackendOrNil(liquidSinglesigNetworkId)
    }
    public var bitcoinSinglesigBackend: GdkNetworkBackend? {
        gdkNetworkBackendOrNil(bitcoinSinglesigNetworkId)
    }
    public var liquidMultisigBackend: GdkNetworkBackend? {
        gdkNetworkBackendOrNil(liquidMultisigNetworkId)
    }
    public var bitcoinMultisigBackend: GdkNetworkBackend? {
        gdkNetworkBackendOrNil(bitcoinMultisigNetworkId)
    }
    public var lwkBackend: LwkNetworkBackend? {
        lwkNetworkBackendOrNil(lwkNetworkId)
    }
}
