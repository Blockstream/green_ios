import Foundation

public extension Encodable {

    func encoded() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    func toDict() -> [String: Any]? {
        if let data = try? encoded() {
            return try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
        }
        return nil
    }

    func stringify() -> String? {
        if let dict = self.toDict(),
            let data = try? JSONSerialization.data(withJSONObject: dict, options: .fragmentsAllowed) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}

public extension Decodable {

    static func from(_ dict: [AnyHashable: Any]) -> Decodable? {
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let json = try? JSONDecoder().decode(self, from: data) {
            return json
        }
        return nil
    }
    static func from(string: String) -> Decodable? {
        guard let data = string.data(using: .utf8, allowLossyConversion: false) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
}
