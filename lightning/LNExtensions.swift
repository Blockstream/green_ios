import Foundation
import UIKit

extension UInt64 {
    public var satoshi: UInt64 { self / 1000 }
    public var milliSatoshi: UInt64 { self * 1000 }
}
extension Int64 {
    public var satoshi: Int64 { self / 1000 }
    public var milliSatoshi: Int64 { self * 1000 }
}
/*
extension LnInvoice {
    public var amountSatoshi: UInt64? { amountMsat?.satoshi }
    public var isAmountLocked: Bool { amountMsat != nil }
    public var expireIn: TimeInterval { TimeInterval(timestamp + expiry) }
    public var expireInAsDate: Date { Date(timeIntervalSince1970: expireIn) }
    public var timeUntilExpiration: Double { Date().distance(to: expireInAsDate) }
    public var expiringInMinutes: Int? { Calendar.current.dateComponents([.minute], from: expireInAsDate, to: Date()).minute }
    public var isExpired: Bool { timeUntilExpiration < 0 }
    public func sendableSatoshi(userSatoshi: UInt64?) -> UInt64? {
        isAmountLocked ? amountSatoshi ?? 0 : userSatoshi
    }
    public func receiveAmountSatoshi(openingFeeParams: OpeningFeeParams?) -> UInt64 {
        (amountMsat?.satoshi ?? 0) - (openingFeeParams?.minMsat.satoshi ?? 0)
    }
}*/

extension Array<Array<String>>? {
    public var lnUrlPayDescription: String? {
        self?.first { "text/plain" == $0.first }?
            .last
    }
    public var lnUrlPayImage: UIImage? {
        guard let base64 = self?.first(where: { "image/png;base64" == $0.first })?.last else { return nil }
        return [base64]
            .compactMap { Data($0.utf8).base64EncodedData() }
            .compactMap { UIImage(data: $0) }
            .first
    }
}

extension String {
    public var errorMessage: String? {
        if #available(iOSApplicationExtension 16.0, *) {
            let txt = String(self.replacingOccurrences(of: "\\", with: "").utf8)
            if let startIndex = txt.ranges(of: "message: \"").last?.upperBound,
               let endIndex = txt.suffix(from: startIndex).firstIndex(of: "\"") {
                return String(txt[startIndex..<endIndex])
            }
        }
        return nil
    }
}
