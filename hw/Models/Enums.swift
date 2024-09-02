import Foundation

public enum JadeBoardType: String, CaseIterable, Codable {
    case v1 = "JADE"
    case v1_1 = "JADE_V1.1"
    case v2 = "JADE_V2"
}

public enum JadeFmwPath: String, CaseIterable, Codable {
    case v1 = "jade"
    case v1_1 = "jade1.1"
    case v2 = "jade2.0"
}

extension JadeFmwPath {
    static func from(_ jadeBoardType: JadeBoardType) -> JadeFmwPath {
        switch jadeBoardType {
        case .v1: JadeFmwPath.v1
        case .v1_1: JadeFmwPath.v1_1
        case .v2: JadeFmwPath.v2
        }
    }
}
