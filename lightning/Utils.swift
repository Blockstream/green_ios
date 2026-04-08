import Foundation

extension Data {
    public func toHex() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
    
}
extension String {
    public func fromHex() -> Data? {
        var data = Data(capacity: count / 2)
        let regex = try? NSRegularExpression(pattern: "[0-9a-fA-F]{2}", options: .caseInsensitive)
        let matches = regex?.matches(in: self, range: NSRange(location: 0, length: count))

        for match in matches ?? [] {
            let byteString = (self as NSString).substring(with: match.range)
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            }
        }
        return data
    }
}
