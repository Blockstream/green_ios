import Foundation

public typealias Assets = [String: Int64]

extension Assets {

    public var manyAssets: Int {
        filter { $0.value > 0 }.keys.count
    }

    public func hasAsset(_ assetId: String) -> Bool {
        filter { $0.key == assetId && $0.value > 0 }.count > 0
    }
    public func hasFunds(_ assetId: String) -> Bool {
        values.reduce(0, +) > 0
    }

    public func balance(_ assetId: String) -> Int64? {
        return first(where: { $0.key == assetId })?.value
    }

    public func policyAsset() -> Int64? {
        for asset in AssetInfo.all {
            if let policyAsset = balance(asset.assetId) {
                return policyAsset
            }
        }
        return nil
    }

    public func toList() -> AssetAmountList {
        AssetAmountList(self)
    }
}
