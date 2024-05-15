import Foundation
import gdk
import greenaddress
import core

class ReEnable2faViewModel {

    let expiredSubaccounts: [WalletItem]

    internal init(expiredSubaccounts: [WalletItem]) {
        self.expiredSubaccounts = expiredSubaccounts
    }

    func sendAmountViewModel(subaccount: WalletItem) async throws -> SendAmountViewModel {
        let createTx = CreateTx(
            subaccount: subaccount,
            txType: .redepositExpiredUtxos
        )
        return SendAmountViewModel(createTx: createTx)
    }
}
