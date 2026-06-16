import UIKit
import hw

enum JadeVersion: String {
    case v1
    case v2
}

extension JadeVersion {
    init?(boardType: JadeBoardType?) {
        guard let boardType = boardType else { return nil }
        switch boardType {
        case .v1, .v1_1:
            self = .v1
        case .v2, .v2c:
            self = .v2
        default:
            self = .v2
        }
    }
}

enum JadeImage: String {
    case normalDual = "il_jade_normal_dual"
    case select = "il_jade_select"
    case selectDual = "il_jade_select_dual"
    case load   = "il_jade_load"
    case horizontal   = "il_jade_horizontal"
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
