import Foundation
public enum CodingError: Error {
    case dictEncodingFailed
}

// MARK: - Dictionary Encoder & Decoder
public final class DictionaryEncoder {
    private let encoder: JSONEncoder

    public init(encoder: JSONEncoder = JSONEncoder()) {
        self.encoder = encoder
    }

    public func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try encoder.encode(value)
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments)

        guard let dictionary = jsonObject as? [String: Any] else {
            throw CodingError.dictEncodingFailed
        }
        return dictionary
    }
}

public final class DictionaryDecoder {
    private let decoder: JSONDecoder

    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    public func decode<T: Decodable>(_ type: T.Type = T.self, from dictionary: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        return try data.decode(type, using: decoder)
    }
}

// MARK: - Data Extension
public extension Data {
    /// Decodes raw data into a Decodable type.
    func decode<T: Decodable>(_ type: T.Type = T.self, using decoder: JSONDecoder = JSONDecoder()) throws -> T {
        return try decoder.decode(T.self, from: self)
    }
}

// MARK: - Codable Extensions
public extension Encodable {
    /// Converts an Encodable object into a [String: Any] dictionary.
    func asDictionary(using encoder: JSONEncoder = JSONEncoder()) throws -> [String: Any] {
        return try DictionaryEncoder(encoder: encoder).encode(self)
    }
}

public extension Dictionary where Key == String, Value == Any {
    /// Decodes a [String: Any] dictionary into a Decodable object.
    func decode<T: Decodable>(_ type: T.Type = T.self, using decoder: JSONDecoder = JSONDecoder()) throws -> T {
        return try DictionaryDecoder(decoder: decoder).decode(type, from: self)
    }
}
