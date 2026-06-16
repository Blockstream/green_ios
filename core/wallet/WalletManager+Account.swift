extension WalletManager {

    // List of accounts for networks / types
    public var bitcoinSubaccounts: [Account] {
        accounts.filter { bitcoinNetworkIds.contains($0.networkId) }
    }
    public var liquidSubaccounts: [Account] {
        accounts.filter { liquidNetworkIds.contains($0.networkId) }
    }
    public var lightningSubaccounts: [Account] {
        accounts.filter { $0.type == .lightning }
    }
    public var liquidAmpSubaccounts: [Account] {
        liquidSubaccounts.filter { $0.type == .ampAccount || $0.type == .amp2Account }
    }
    // List of accounts with funds
    public func subaccountsFor(assetId: String) -> [Account] {
        switch assetId {
        case AssetInfo.lightningId:
            return lightningSubaccounts
        case AssetInfo.btcId:
            return bitcoinSubaccounts
        default:
            if getAsset(assetId).amp ?? false {
                return liquidAmpSubaccounts
            } else {
                return liquidSubaccounts
            }
        }
    }
    public func subaccountsWithFunds(assetId: String) -> [Account] {
        (bitcoinSubaccounts + lightningSubaccounts + liquidSubaccounts)
            .filter {
                accountBackendOrNil($0)?.assets
                    .filter { $0.key == assetId }
                    .compactMap { $0.value }
                    .reduce(0, +) ?? 0 > 0
            }
    }
    public func bitcoinSubaccountsWithFunds() -> [Account] {
        bitcoinSubaccounts
            .filter {
                accountBackendOrNil($0)?.assets
                    .compactMap{ $0.value }
                    .reduce(0, +) ?? 0 > 0
            }
    }
    public func liquidSubaccountsWithFunds() -> [Account] {
        liquidSubaccounts
            .filter {
                accountBackendOrNil($0)?.assets
                    .compactMap{ $0.value }
                    .reduce(0, +) ?? 0 > 0
            }
    }

    public func liquidSubaccountsWithAssetIdFunds(assetId: String) -> [Account] {
        liquidSubaccounts
            .filter {
                accountBackendOrNil($0)?.assets
                    .filter { $0.key == assetId }
                    .compactMap { $0.value }
                    .reduce(0, +) ?? 0 > 0
            }
    }

}
