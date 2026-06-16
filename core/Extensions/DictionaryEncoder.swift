import Foundation

public final class DictionaryEncoder {
    private let encoder = JSONEncoder() // Reuses compiler Codable synthesization

    public init() {}

    public func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try encoder.encode(value)
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw NSError(domain: "DictionaryEncoder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to render top-level dictionary allocation shape."])
        }
        return dictionary
    }
}

public final class DictionaryDecoder {
    private let decoder = JSONDecoder()

    public init() {}

    public func decode<T: Decodable>(_ type: T.Type, from dictionary: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        return try decoder.decode(T.self, from: data)
    }
}

extension Encodable {
    func asDictionary() throws -> [String: Any] {
        return try DictionaryEncoder().encode(self)
    }
}

extension Dictionary where Key == String, Value == Any {
    func decodeTo<T: Decodable>(_ type: T.Type) throws -> T {
        return try DictionaryDecoder().decode(type, from: self)
    }
}
