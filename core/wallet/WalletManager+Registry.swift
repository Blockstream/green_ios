import Foundation
import UIKit

extension WalletManager {
    public func getAsset(_ assetId: String?) -> AssetInfo {
        let info = registry.info(for: assetId ?? "", provider: self)
        return AssetInfo(
            assetId: info.assetId,
            name: info.name,
            precision: info.precision ?? 8,
            ticker: info.ticker
        )
    }
    public func hasAssetIcon(_ assetId: String?) -> Bool {
        registry.hasImage(for: assetId ?? "", provider: self)
    }
    public func info(for key: String?) -> AssetInfo {
        registry.info(for: key ?? "", provider: self)
    }

    public func image(for key: String?) -> UIImage {
        registry.image(for: key ?? "", provider: self)
    }

    public func hasImage(for key: String?) -> Bool {
        registry.hasImage(for: key ?? "", provider: self)
    }

    public func refreshRegistryIfNeeded() async throws {
        let interval = CFAbsoluteTimeGetCurrent() - (updatedRegistryAt ?? .zero)
        if updatedRegistryAt == nil || interval > 120 {
            registry.refresh(provider: self)
            updatedRegistryAt = CFAbsoluteTimeGetCurrent()
            newNotificationDelegate?
                .didReceive(event: .refreshAssets, networkId: .electrumLiquid)
        }
    }
}
extension WalletManager: AssetsProvider {
    public func getAssets(params: GetAssetsParams) -> GetAssetsResult? {
        let networkId = activeGdkLiquidNetworkIds.first ?? .electrumLiquid
        let gdkNetworkBackend = gdkNetworkBackendOrNil(networkId)
        return gdkNetworkBackend?.session.getAssets(params: params)
    }

    public func refreshAssets(icons: Bool, assets: Bool) async throws {
        let networkId = activeGdkLiquidNetworkIds.first ?? .electrumLiquid
        let gdkNetworkBackend = gdkNetworkBackendOrNil(networkId)
        try await gdkNetworkBackend?.session
            .refreshAssets(icons: icons, assets: assets)
    }
}
