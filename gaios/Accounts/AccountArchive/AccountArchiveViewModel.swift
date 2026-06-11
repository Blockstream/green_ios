import Foundation
import UIKit
import core


class AccountArchiveViewModel {

    var wm: WalletManager { WalletManager.current! }

    /// load visible subaccounts
    var subaccounts: [Account] {
        wm.subaccounts.filter { $0.hidden }
    }
    var list: [Account] = []
    /// cell models
    var accountCellModels = [AccountArchiveCellModel]()

    func loadSubaccounts() async throws {
        let subaccounts = try await wm.subaccounts().filter { $0.hidden }
        _ = try? await wm.balances(subaccounts: subaccounts)
        self.accountCellModels = subaccounts.map { AccountArchiveCellModel(account: $0, satoshi: $0.btc) }
    }
    func unarchiveSubaccount(_ subaccount: Account) async throws {
        guard let session = WalletManager.current?.sessions[subaccount.gdkNetwork.network] else { return }
        let params = UpdateSubaccountParams(subaccount: subaccount.pointer, hidden: false)
        try? await session.updateSubaccount(params)
        try? await loadSubaccounts()
    }
    var hideBalance: Bool {
        get {
            return UserDefaults.standard.bool(forKey: AppStorageConstants.hideBalance.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: AppStorageConstants.hideBalance.rawValue)
        }
    }
}
