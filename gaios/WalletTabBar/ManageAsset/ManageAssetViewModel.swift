import Foundation
import UIKit
import gdk
import greenaddress
import hw
import core

class ManageAssetViewModel {

    var wm: WalletManager? { WalletManager.current }
    var session: SessionManager? { wm?.prominentSession }
    var settings: Settings? { session?.settings }
    var paused: Bool { !(wm?.activeSessions.filter { $0.value.paused }.isEmpty ?? false) }

    /// load visible subaccounts
    var subaccounts: [WalletItem] { wm?.subaccounts.filter { !($0.hidden) } ?? [] }
    var watchOnly: Bool { wm?.isWatchonly ?? false}

    /// Cached data
    var cachedTransactions = [Transaction]()
    var cachedMeldTransactions = [Transaction]()

    var walletModel: WalletModel?

    /// cell models
    var txCellModels = [TransactionCellModel]()

    var accountCellModels: [AccountCellModel] {
        var list = [AccountCellModel]()
        for account in accounts() {
            let satohi = account.satoshi?[assetId]
            list += [
                AccountCellModel(
                    account: account,
                    satoshi: satohi,
                    assetId: assetId)]
        }
        return list
    }
    var hideBalance: Bool {
        get {
            return UserDefaults.standard.bool(forKey: AppStorageConstants.hideBalance.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: AppStorageConstants.hideBalance.rawValue)
        }
    }

    var fetchingTxs = false
    var currency: String? {
        if let settings = settings {
            return settings.pricing["currency"]
        }
        return nil
    }
    var assetId: String
    var satoshi: Int64 = 0
    var account: WalletItem?
    var isBTCAsset: Bool {
        "BTC" == assetId.uppercased()
    }
    init(assetId: String, account: WalletItem? = nil, walletModel: WalletModel?) {
        self.assetId = assetId
        self.walletModel = walletModel
        if let account {
            self.account = account
            return
        }
        if accounts().count == 1 {
            self.account = accounts()[0]
        }
    }
    func fetchBalances() async throws {
        if let account {
            self.satoshi = account.satoshi?[assetId] ?? 0
        } else {
            var sum: Int64 = 0
            for account in accounts() {
                sum += account.satoshi?[assetId] ?? 0
            }
            self.satoshi = sum
        }
    }
    func existPendingTransaction() -> Bool {
        for tx in cachedTransactions where tx.blockHeight == 0 {
            return true
        }
        return false
    }
    func fetchTransactions() async throws {
        guard let wm = wm, !fetchingTxs else {
            return
        }
        fetchingTxs = true

        let txs = try await wm.allTransactions(subaccounts: account == nil ? accounts() : [account!])
        cachedTransactions = txs.filter {
            for amount in $0.amounts where amount.key == assetId {
                return true
            }
            return false
        }
        // get meld transactions
        if let account, let walletModel {
            if let cachedMeldTransactions = try? await walletModel.getMeldTransactions(account) {
                self.cachedMeldTransactions = cachedMeldTransactions
            }
        }
        txCellModels = (cachedMeldTransactions + cachedTransactions)
            .map { tx in
                let blockHeight = tx.isLiquid ? wm.liquidBlockHeight() : wm.bitcoinBlockHeight()
                return TransactionCellModel(tx: tx, blockHeight: blockHeight ?? 0)
            }

        fetchingTxs = false
    }

    func isSweepEnabled() -> Bool {
        if watchOnly {
            let notMultisigBitcoinNetworks = subaccounts.filter { $0.networkType.singlesig || $0.networkType.liquid }
            return notMultisigBitcoinNetworks.isEmpty
        }
        return false
    }

    func accounts() -> [WalletItem] {
        subaccounts.filter({ $0.satoshi?.keys.contains(assetId) ?? false })
    }
    func renameSubaccount(name: String) async throws {
        guard let account = account, let session = wm?.sessions[account.gdkNetwork.network] else {
            return
        }
        let params = UpdateSubaccountParams(subaccount: account.pointer, name: name)
        try await session.renameSubaccount(params)
        self.account = try await wm?.subaccountUpdate(account: account)
    }
    func archiveSubaccount() async throws {
        guard let account = account, let session = wm?.sessions[account.gdkNetwork.network] else {
            return
        }
        let params = UpdateSubaccountParams(subaccount: account.pointer, hidden: true)
        try await session.updateSubaccount(params)
        self.account = try await wm?.subaccountUpdate(account: account)
    }
    var isFunded: Bool? {
        if let account {
            if account.satoshi == nil { return false }
            if let sats = account.satoshi?[assetId] {
                return sats > 0
            }
        }
        return nil
    }
}
