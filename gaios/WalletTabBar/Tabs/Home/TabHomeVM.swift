import Foundation
import UIKit
import core
import greenaddress

class TabHomeVM: TabViewModel {
    var subaccounts: [Account]? {
        state.subaccounts
    }
    var balances: [String: Int64]? {
        state.balances
    }
    var hideBalance: Bool {
        state.hideBalance
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
        if let settings = wallet.prominentSession.settings {
            return settings.pricing["currency"]
        }
        return nil
    }
    func rotateBalanceDisplayMode() async {
        try? await walletDataModel.rotateBalanceDisplayMode()
    }
    func hideBalance(_ value: Bool) async {
        try? await walletDataModel.hideBalance(value)
    }
    func relogin() async throws {
        guard let credentials = try? await wallet.prominentSession.getCredentials(password: "") else {
            throw GaError.NotAuthorizedError("")
        }
        let lightningCredentials = try? AuthenticationTypeHandler.getCredentials(method: .AuthKeyLightning, for: mainWallet.keychainLightning)
        let boltzCredentials = try? AuthenticationTypeHandler.getCredentials(method: .AuthKeyBoltz, for: mainWallet.keychain)
        _ = try await wallet.login(
            credentials: credentials,
            lightningCredentials: lightningCredentials,
            boltzCredentials: boltzCredentials,
            device: wallet.hwDevice,
            fullRestore: false,
            creation: false)
        _ = try await wallet.getAccounts()
    }
    func getExpiredSubaccounts() async -> [Account]? {
        let expired = try? await wallet.getExpiredSubaccounts()
        if let expired = expired, !expired.isEmpty && !mainWallet.isWatchonly {
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
        if BackupHelper.shared.needsBackup(walletId: mainWallet.id) &&
            BackupHelper.shared.isDismissed(walletId: mainWallet.id, position: .homeTab) == false &&
            state.totals?.1 ?? 0 > 0 && !state.subaccounts.isEmpty {
            cards.append(.backup)
        }
        return cards
    }
}
