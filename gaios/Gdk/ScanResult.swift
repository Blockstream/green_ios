import Foundation
import gdk

struct ScanResult: Codable {
    enum CodingKeys: String, CodingKey {
        case result
        case bcur
    }
    public let result: String
    public let bcur: BcurDecodedData?
    static func from(bcurDecodedData: BcurDecodedData) -> ScanResult {
        ScanResult(result: bcurDecodedData.result, bcur: bcurDecodedData)
    }
}
