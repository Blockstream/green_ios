import Foundation
import gdk

public typealias ScanResult = [String: Any?]
extension ScanResult {
    private func get<T>(_ key: String) -> T? {
        return self[key] as? T
    }
    public var result: String? { self.get("result") }
    public var bcur: BcurDecodedData? { self.get("bcur") }
    public static func from(result: String?, bcur: BcurDecodedData?) -> ScanResult {
        var res = ScanResult()
        res["result"] = result ?? bcur?.result
        res["bcur"] = bcur
        return res
    }
}
