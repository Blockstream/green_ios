import Foundation

public enum JadeBoardType: String, CaseIterable, Codable {
    case v1 = "JADE"
    case v1_1 = "JADE_V1.1"
    case v2 = "JADE_V2"
    case v2c = "JADE_V2C"
    case unknown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = JadeBoardType(rawValue: raw) ?? .unknown
    }
}

public enum JadeFmwPath: String, CaseIterable, Codable {
    case v1 = "jade"
    case v1_1 = "jade1.1"
    case v2 = "jade2.0"
    case v2c = "jade2.0c"
}

extension JadeFmwPath {
    static func from(_ jadeBoardType: JadeBoardType) throws -> JadeFmwPath {
        switch jadeBoardType {
        case .v1:
            return JadeFmwPath.v1
        case .v1_1:
            return JadeFmwPath.v1_1
        case .v2:
            return JadeFmwPath.v2
        case .v2c:
            return JadeFmwPath.v2c
        case .unknown:
            throw HWError.Abort("Unsupported hardware")
        }
    }
}
