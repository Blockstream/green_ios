import UIKit
enum JadeVersion: String {
    case v1
    case v2
}

enum JadeImage: String {
    case normal = "il_jade_normal"
    case normalDual = "il_jade_normal_dual"
    case select = "il_jade_select"
    case selectDual = "il_jade_select_dual"
    case secure = "il_jade_secure"
    case logo   = "il_jade_logo"
    case load   = "il_jade_load"
}

class JadeAsset {
    static var defaultVersion: JadeVersion {
        return .v2
    }
    static func img(_ name: JadeImage, _ version: JadeVersion?) -> UIImage {
        let name = name.rawValue + "_" + (version?.rawValue ?? defaultVersion.rawValue)
        return UIImage(named: name)!
    }
}
