import Foundation
import gdk
import greenaddress
import core

class ReEnable2faViewModel {

    let expiredSubaccounts: [WalletItem]
    var subaccount: WalletItem?

    internal init(expiredSubaccounts: [WalletItem]) {
        self.expiredSubaccounts = expiredSubaccounts
    }

    func sendAmountViewModel() -> SendAmountViewModel? {
        guard let subaccount = subaccount else { return nil }
        var createTx = CreateTx(
            subaccount: subaccount,
            txType: .redepositExpiredUtxos
        )
        return SendAmountViewModel(createTx: createTx)
    }
}
