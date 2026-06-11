import Foundation

import greenaddress
import core

class ReEnable2faViewModel {

    let expiredSubaccounts: [Account]
    var subaccount: Account?

    internal init(expiredSubaccounts: [Account]) {
        self.expiredSubaccounts = expiredSubaccounts
    }

    func sendAmountViewModel() -> SendAmountViewModelLegacy? {
        guard let subaccount = subaccount else { return nil }
        var createTx = CreateTx(
            subaccount: subaccount,
            txType: .redepositExpiredUtxos
        )
        return SendAmountViewModelLegacy(createTx: createTx)
    }
}
