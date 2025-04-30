import Foundation
import UIKit
import gdk

public protocol AssetsProvider {
    func getAssets(params: GetAssetsParams) -> GetAssetsResult?
    func refreshAssets(icons: Bool, assets: Bool, refresh: Bool) async throws
}

public class AssetsManager {

    private let testnet: Bool
    private var infos = [String: AssetInfo?]()
    private var icons = [String: String?]()
    private var uncached = [String]()
    private let qos = DispatchQueue(label: "AssetsManagerDispatchQueue", qos: .userInteractive)
    private var updatedAt: TimeInterval?

    public init(testnet: Bool) {
        self.testnet = testnet
        if testnet {
            infos = [AssetInfo.testId: AssetInfo.test,
                     AssetInfo.ltestId: AssetInfo.ltest]
        } else {
            infos = [AssetInfo.btcId: AssetInfo.btc,
                     AssetInfo.lbtcId: AssetInfo.lbtc,
                     AssetInfo.lightningId: AssetInfo.lightning]
        }
    }

    public var all: [AssetInfo] {
        return infos.compactMap { $0.value }
    }

    private func getAsset(for key: String, provider: AssetsProvider) {
        let assets = provider.getAssets(params: GetAssetsParams(assetsId: [key]))
        if let assets = assets {
            infos.merge(assets.assets.isEmpty ? [key: nil] : assets.assets, uniquingKeysWith: {_, new in new})
            icons.merge(assets.icons.isEmpty ? [key: nil] : assets.icons, uniquingKeysWith: {_, new in new})
        }
    }

    private func getInfo(for key: String, provider: AssetsProvider) -> AssetInfo? {
        let main = [AssetInfo.btc, AssetInfo.lbtc, AssetInfo.test, AssetInfo.ltest, AssetInfo.lightning].filter { $0.assetId == key }.first
        if let main = main {
            return main
        }
        if !infos.keys.contains(key) {
            getAsset(for: key, provider: provider)
        }
        if let asset = infos[key], let asset = asset {
            return asset
        }
        return nil
    }

    private func getImage(for key: String, provider: AssetsProvider) -> UIImage? {
        if [AssetInfo.btcId, AssetInfo.testId].contains(key) {
            return UIImage(named: testnet ? "ntw_testnet" : "ntw_btc")
        } else if AssetInfo.lightningId == key {
            return UIImage(named: "lightning_btc" )
        }
        if !icons.keys.contains(key) {
            getAsset(for: key, provider: provider)
        }
        if let icon = icons[key], let icon = icon {
            return UIImage(base64: icon)
        }
        return nil
    }

    public func info(for key: String, provider: AssetsProvider) -> AssetInfo {
        return qos.sync() { getInfo(for: key, provider: provider) ?? AssetInfo(assetId: key, name: nil, precision: 0, ticker: nil) }
    }

    public func image(for key: String, provider: AssetsProvider) -> UIImage {
        return qos.sync() { getImage(for: key, provider: provider) ?? UIImage(named: "default_asset_icon") ?? UIImage() }
    }

    public func hasImage(for key: String?, provider: AssetsProvider) -> Bool {
        return qos.sync() { getImage(for: key ?? "", provider: provider) != nil }
    }

    public func refreshIfNeeded(provider: AssetsProvider) async throws {
        let interval = CFAbsoluteTimeGetCurrent() - (updatedAt ?? .zero)
        if updatedAt == nil || interval > 120 {
            try await provider.refreshAssets(icons: true, assets: true, refresh: true)
            try await self.fetchFromCountly(provider: provider)
            updatedAt = CFAbsoluteTimeGetCurrent()
            let notification = NSNotification.Name(rawValue: EventType.AssetsUpdated.rawValue)
            NotificationCenter.default.post(name: notification, object: nil, userInfo: nil)
        }
    }

    public func cache(provider: AssetsProvider) async throws {
        try await provider.refreshAssets(icons: true, assets: true, refresh: false)
    }

    public func getAssetsFromCountly() async throws -> [EnrichedAsset] {
        let assets = AnalyticsManager.shared.getRemoteConfigValue(key: AnalyticsManager.countlyRemoteConfigAssets) as? [[String: Any]]
        let json = try? JSONSerialization.data(withJSONObject: assets ?? [], options: [])
        let res = try? JSONDecoder().decode([EnrichedAsset].self, from: json ?? Data())
        return res ?? []
    }

    public func fetchFromCountly(provider: AssetsProvider) async throws {
        let assets = try await getAssetsFromCountly()
        let res = provider.getAssets(params: GetAssetsParams(assetsId: assets.map { $0.id }))
        qos.sync() {
            self.infos.merge(res?.assets ?? [:], uniquingKeysWith: {_, new in new})
            self.icons.merge(res?.icons ?? [:], uniquingKeysWith: {_, new in new})
            assets.forEach {
                self.infos[$0.id]??.amp = $0.amp ?? false
                self.infos[$0.id]??.weight = $0.weight ?? 0
            }
        }
    }

    public func sortAssets(lhs: String, rhs: String) -> Bool {
        if [AssetInfo.btcId, AssetInfo.testId].contains(lhs) { return true }
        if [AssetInfo.btcId, AssetInfo.testId].contains(rhs) { return false }
        if [AssetInfo.lbtcId, AssetInfo.ltestId].contains(lhs) { return true }
        if [AssetInfo.lbtcId, AssetInfo.ltestId].contains(rhs) { return false }
        let lhsImage = icons[lhs] != nil
        let rhsImage = icons[rhs] != nil
        if lhsImage && !rhsImage { return true }
        if !lhsImage && rhsImage { return false }
        let lhsInfo = infos[lhs]
        let rhsInfo = infos[rhs]
        if lhsInfo??.ticker != nil && rhsInfo??.ticker == nil { return true }
        if lhsInfo??.ticker == nil && rhsInfo??.ticker != nil { return false }
        let lhsw = lhsInfo??.weight ?? 0
        let rhsw = rhsInfo??.weight ?? 0
        if lhsw != rhsw {
            return lhsw > rhsw
        }
        return lhs < rhs
    }
}
