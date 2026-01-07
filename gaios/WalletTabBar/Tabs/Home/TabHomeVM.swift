import Foundation
import UIKit
import core
import gdk

class TabHomeVM: TabViewModel {
    var subaccounts: [WalletItem]? {
        state.subaccounts
    }
    var balances: [String: Int64]? {
        state.balances
    }
    var totals: (String, Int64)? {
        state.totals
    }
    var assetAmountList: AssetAmountList? {
        state.assetAmountList
    }
    var priceCache: PriceChartModel? {
        state.priceCache
    }
    var alertCards: [AlertCardType]  {
        state.alertCards
    }
    var promos: [PromoCellModel]  {
        state.promos
    }
    var balanceDisplayMode: BalanceDisplayMode  {
        state.balanceDisplayMode
    }
    var defaultCurrency: String? {
        if let settings = wallet.prominentSession?.settings {
            return settings.pricing["currency"]
        }
        return nil
    }
    func rotateBalanceDisplayMode() async {
        try? await walletDataModel.rotateBalanceDisplayMode()
    }
    func relogin() async throws {
        let credentials = try? await wallet.prominentSession?.getCredentials(password: "")
        let lightningCredentials = try? AuthenticationTypeHandler.getCredentials(method: .AuthKeyLightning, for: mainAccount.keychainLightning)
        let boltzCredentials = try? AuthenticationTypeHandler.getCredentials(method: .AuthKeyBoltz, for: mainAccount.keychain)
        let walletIdentifier = try wallet.prominentSession?.walletIdentifier(credentials: credentials)
        _ = try await wallet.login(
            credentials: credentials,
            lightningCredentials: lightningCredentials,
            boltzCredentials: boltzCredentials,
            device: wallet.hwDevice,
            masterXpub: nil,
            fullRestore: false,
            creation: false,
            parentWalletId: walletIdentifier)
        _ = try await wallet.subaccounts()
    }
    func getExpiredSubaccounts() async -> [WalletItem]? {
        let expired = try? await wallet.getExpiredSubaccounts()
        if let expired = expired, !expired.isEmpty && !mainAccount.isWatchonly {
            return expired
        }
        return nil
    }
    func dismissRemoteAlert() {
        state.remoteAlerts?.removeFirst()
        refresh(features: [.alertCards])
    }
    var backupCards: [AlertCardType]  {
        fetchBackupCards()
    }
    func fetchBackupCards() -> [AlertCardType] {
        var cards: [AlertCardType] = []
        if BackupHelper.shared.needsBackup(walletId: mainAccount.id) &&
            BackupHelper.shared.isDismissed(walletId: mainAccount.id, position: .homeTab) == false &&
            state.totals?.1 ?? 0 > 0 && !state.subaccounts.isEmpty {
            cards.append(.backup)
        }
        return cards
    }
}
