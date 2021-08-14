import Foundation
import UIKit
import PromiseKit

struct AssentEntity: Codable {
    let domain: String
}

struct AssetInfo: Codable {

    enum CodingKeys: String, CodingKey {
        case assetId = "asset_id"
        case name
        case precision
        case ticker
        case entity
    }

    var assetId: String
    var name: String
    var precision: UInt8?
    var ticker: String?
    var entity: AssentEntity?

    init(assetId: String, name: String, precision: UInt8, ticker: String) {
        self.assetId = assetId
        self.name = name
        self.precision = precision
        self.ticker = ticker
    }

    func encode() -> [String: Any]? {
        return try? JSONSerialization.jsonObject(with: JSONEncoder().encode(self), options: .allowFragments) as? [String: Any]
    }
}

enum RegistryFailStatus {
    case assets
    case icons
    case all
    case none
}

class Registry: Codable {
    static let shared = Registry(infos: [:], icons: [:])
    var infos: [String: AssetInfo]
    var icons: [String: String]

    var iconsTask: Bool = false
    var assetsTask: Bool = false

    init(infos: [String: AssetInfo], icons: [String: String]) {
        self.infos = infos
        self.icons = icons
    }

    func image(for key: String?) -> UIImage? {
        let network = getGdkNetwork(getNetwork())
        let id = "btc" == key ? network.policyAsset : key
        if let path = Bundle.main.path(forResource: "asset_\(id ?? "")", ofType: "png") {
            // read icon from file
            return UIImage(contentsOfFile: path)
        } else if let icon = icons.filter({ $0.key == id }).first {
            // read icon from memory
            return UIImage(base64: icon.value)
        }
        return UIImage(named: "default_asset_icon")
    }

    func failStatus() -> RegistryFailStatus {
        if assetsTask == false && iconsTask == false { return .all }
        if assetsTask == false { return .assets }
        if iconsTask == false { return .icons }
        return .none
    }

    @discardableResult
    func fetchIcons(refresh: Bool) -> Bool {
        guard let data = try? SessionManager.shared.refreshAssets(params: ["icons": true, "assets": false, "refresh": refresh]) else {
            return false
        }
        var iconsData = data["icons"] as? [String: String]
        if let modIndex = iconsData?.keys.firstIndex(of: "last_modified") {
            iconsData?.remove(at: modIndex)
        }
        self.icons = iconsData ?? [:]
        return iconsData != nil
    }

    @discardableResult
    func fetchAssets(refresh: Bool) -> Bool {
        guard let data = try? SessionManager.shared.refreshAssets(params: ["icons": false, "assets": true, "refresh": refresh]) else {
            return false
        }
        var infosData = data["assets"] as? [String: Any]
        if let modIndex = infosData?.keys.firstIndex(of: "last_modified") {
            infosData?.remove(at: modIndex)
        }
        let infosSer = try? JSONSerialization.data(withJSONObject: infosData ?? [:])
        let infos = try? JSONDecoder().decode([String: AssetInfo].self, from: infosSer ?? Data())
        self.infos = infos ?? [:]
        return infos != nil
    }

    func cache() {
        return refresh(refresh: false)
    }

    func refresh(refresh: Bool = true) {

        iconsTask = fetchIcons(refresh: false)
        assetsTask = fetchAssets(refresh: refresh)

        if refresh && !assetsTask {
            //remote refresh failed for assetes, than try refresh from cache
            fetchAssets(refresh: false)
        }

    }

    func load() -> Promise<Void> {
        let bgq = DispatchQueue.global(qos: .background)
        return Promise()
            .compactMap(on: bgq) { self.refresh(refresh: true) }
    }
}
