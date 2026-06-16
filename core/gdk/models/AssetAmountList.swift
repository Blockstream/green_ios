import Foundation
import UIKit

public class AssetAmountList {

    public var amounts: [(String, Int64)]
    public var assets: [String: AssetInfo]  = [:]
    public var hasImages: [String: Bool]  = [:]
    public var ids: [String] { amounts.map { $0.0} }

    public init(_ amounts: [String: Int64]) {
        let registry = WalletManager.current
        for assetId in amounts.keys {
            let assetInfo = registry?.info(for: assetId)
            assets[assetId] = assetInfo
            let hasImage = registry?.hasImage(for: assetId)
            hasImages[assetId] = hasImage ?? false
        }
        self.amounts = amounts.map { ($0.key, $0.value) }
        self.amounts = sorted()
    }

    public static func from(assetIds: [String]) -> AssetAmountList {
        let assetIds = assetIds.map { ($0, Int64(0)) }
        let dict = Dictionary(uniqueKeysWithValues: assetIds)
        return AssetAmountList(dict)
    }

    public func policyAsset() -> Int64 {
        amounts.filter { AssetInfo.baseIds.contains($0.0) }.map { $0.1 }.reduce(0, { (res, partial) in res + partial })
    }

    public func sortAssets(lhs: String, rhs: String) -> Bool {
        if [AssetInfo.btcId, AssetInfo.testId].contains(lhs) { return true }
        if [AssetInfo.btcId, AssetInfo.testId].contains(rhs) { return false }
        if [AssetInfo.lightningId].contains(lhs) { return true }
        if [AssetInfo.lightningId].contains(rhs) { return false }
        if [AssetInfo.lbtcId, AssetInfo.ltestId].contains(lhs) { return true }
        if [AssetInfo.lbtcId, AssetInfo.ltestId].contains(rhs) { return false }
        let lhsImage = hasImages[lhs] ?? false
        let rhsImage = hasImages[rhs] ?? false
        if lhsImage && !rhsImage { return true }
        if !lhsImage && rhsImage { return false }
        let lhsInfo = assets[lhs]
        let rhsInfo = assets[rhs]
        if lhsInfo?.ticker != nil && rhsInfo?.ticker == nil { return true }
        if lhsInfo?.ticker == nil && rhsInfo?.ticker != nil { return false }
        let lhsw = lhsInfo?.weight ?? 0
        let rhsw = rhsInfo?.weight ?? 0
        if lhsw != rhsw {
            return lhsw > rhsw
        }
        return lhs < rhs
    }

    public func sorted() -> [(String, Int64)] {
        return amounts.sorted(by: { (lhs, rhs) in
            return sortAssets(lhs: lhs.0, rhs: rhs.0)
        })
    }

    public func nonZeroAmounts() -> [(String, Int64)] {
        return amounts.filter { $0.1 != 0 }
    }

    public func image(for id: String) -> UIImage {
        return WalletManager.current?.image(for: id) ?? UIImage()
    }
}
