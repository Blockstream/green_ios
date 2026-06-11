import UIKit


class TxDetailsTotalsCellModel {

    var totalSpent: String
    var conversion: String
    var ntwFees: String
    var ntwFeesFiat: String
    var receive: String
    var hideBalance: Bool
    var assetId: String

    init(totalSpent: String,
         conversion: String,
         ntwFees: String,
         ntwFeesFiat: String,
         receive: String,
         assetId: String,
         hideBalance: Bool
    ) {
        self.totalSpent = totalSpent
        self.conversion = conversion
        self.ntwFees = ntwFees
        self.ntwFeesFiat = ntwFeesFiat
        self.receive = receive
        self.hideBalance = hideBalance
        self.assetId = assetId
    }
}
