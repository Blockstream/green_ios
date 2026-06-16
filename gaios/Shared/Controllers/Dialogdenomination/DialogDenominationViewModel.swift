import Foundation
import core

class DialogDenominationViewModel {

    var denomination: DenominationType
    var denominations: [DenominationType]
    var network: NetworkId

    init(denomination: DenominationType,
         denominations: [DenominationType],
         network: NetworkId) {
        self.denomination = denomination
        self.denominations = denominations
        self.network = network
    }

    func symbol(_ denom: DenominationType) -> String {
        return denom.string(for: network.gdkNetwork)
    }
}
