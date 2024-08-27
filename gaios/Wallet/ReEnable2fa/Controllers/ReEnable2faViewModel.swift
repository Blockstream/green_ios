import Foundation
import gdk
import greenaddress
import core

class ReEnable2faViewModel {

    let expiredSubaccounts: [WalletItem]
    var address: Address?
    var subaccount: WalletItem?

    internal init(expiredSubaccounts: [WalletItem]) {
        self.expiredSubaccounts = expiredSubaccounts
    }

    func sendAmountViewModel() -> SendAmountViewModel? {
        guard let subaccount = subaccount, let address = address else { return nil }
        var createTx = CreateTx(
            subaccount: subaccount,
            txType: .redepositExpiredUtxos,
            txAddress: address
        )
        createTx.address = address.address
        return SendAmountViewModel(createTx: createTx)
    }

    func newAddress() async throws {
        guard let subaccount = subaccount else { return }
        let address = try await subaccount.session?.getReceiveAddress(subaccount: subaccount.pointer)
        self.address = address
    }
}
