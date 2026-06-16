import greenaddress

extension WalletManager: ConverterProvider {
    public func convertBitcoinAmount(params: Balance) throws -> Balance? {
        let networkId = activeBitcoinNetworkIds.first ?? prominentNetworkId
        let gdkNetworkBackend = gdkNetworkBackendOrNil(networkId)
        return try gdkNetworkBackend?.convert(params: params)
    }

    public func convertLiquidAmount(params: Balance) throws -> Balance? {
        guard let networkId = activeLiquidNetworkIds.first else {
            throw GaError.GenericError("No liquid network")
        }
        let gdkNetworkBackend = try gdkNetworkBackend(networkId)
        return try gdkNetworkBackend.convert(params: params)
    }
}
