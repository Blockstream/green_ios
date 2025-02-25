import Foundation
import UIKit
import core
import gdk

class AccountArchiveViewModel {

    var wm: WalletManager { WalletManager.current! }

    /// load visible subaccounts
    var subaccounts: [WalletItem] {
        wm.subaccounts.filter { $0.hidden }
    }

    /// cell models
    var accountCellModels = [AccountCellModel]()

    func loadSubaccounts() async throws {
        let subaccounts = try await wm.subaccounts().filter { $0.hidden }
        _ = try? await wm.balances(subaccounts: subaccounts)
        self.accountCellModels = subaccounts.map { AccountCellModel(account: $0, satoshi: $0.btc) }
    }

    func unarchiveSubaccount(_ subaccount: WalletItem) async throws {
        guard let session = WalletManager.current?.sessions[subaccount.gdkNetwork.network] else { return }
        let params = UpdateSubaccountParams(subaccount: subaccount.pointer, hidden: false)
        try? await session.updateSubaccount(params)
        try? await loadSubaccounts()
    }
}
