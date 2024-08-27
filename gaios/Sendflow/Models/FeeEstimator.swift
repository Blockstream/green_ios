import Foundation
import gdk
import greenaddress
import core
import BreezSDK
import lightning

struct FeeEstimator {
    let session: SessionManager

    var defaultMinFee: UInt64 { session.gdkNetwork.liquid ? 100 : 1000 }
    var feeEstimates = [UInt64](repeating: 100, count: 25)
    var minFeeEstimate: UInt64? { feeEstimates.first }
    // var transactionPriority: TransactionPriority = .Medium

    mutating func refreshFeeEstimates() async {
        if let fees = try? await session.getFeeEstimates() {
            self.feeEstimates = fees
        }
    }

    /*var feeRate: UInt64? {
        if transactionPriority.rawValue < feeEstimates.count {
            return feeEstimates[transactionPriority.rawValue]
        }
        return nil
    }*/

    func feeRate(at transactionPriority: TransactionPriority) -> UInt64? {
        if transactionPriority.rawValue < feeEstimates.count {
            return feeEstimates[transactionPriority.rawValue]
        }
        return nil
    }
}
