import Foundation
import UIKit
import core


class AccountArchiveViewModel {

    var wm: WalletManager { WalletManager.current! }

    /// load visible subaccounts
    var subaccounts: [Account] {
        wm.accounts
    }
    var list: [Account] = []
    /// cell models
    var accountCellModels = [AccountArchiveCellModel]()

    func loadSubaccounts() async throws {
        let subaccounts = try await wm.getAccounts().filter { $0.hidden }
        _ = try? await wm.balances(subaccounts: subaccounts)
        self.accountCellModels = subaccounts
            .map {
                AccountArchiveCellModel(
                    account: $0,
                    satoshi: try? $0.assets(wm).policyAsset()
                )
            }
    }
    func unarchiveSubaccount(_ account: Account) async throws {
        let backend = try wm.networkBackend(account.networkId)
        _ = try await wm.updateAccount(account: account, isHidden: false)
        try await loadSubaccounts()
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
