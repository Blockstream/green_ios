import UIKit
import gdk
import core
import Foundation

class TabTransactVM: TabViewModel {
    var txs: [Transaction]? {
        state.txs
    }
    var hideBalance: Bool {
        state.hideBalance
    }
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
    var alertCards: [AlertCardType] {
        state.alertCards
    }
    var backupCards: [AlertCardType] {
        state.backupCards
    }
    var balanceDisplayMode: BalanceDisplayMode {
        state.balanceDisplayMode
    }
    var defaultCurrency: String? {
        if let settings = wallet.prominentSession?.settings {
            return settings.pricing["currency"]
        }
        return nil
    }
    var currentPage: Int {
        get { state.currentPage }
        set { state.currentPage = newValue }
    }
    var txsCanLoadMore: Bool {
        state.txsCanLoadMore
    }
    func rotateBalanceDisplayMode() async {
        try? await walletDataModel.rotateBalanceDisplayMode()
    }
    func getBoltzKey() throws -> Credentials {
        try AuthenticationTypeHandler.getCredentials(method: .AuthKeyBoltz, for: mainAccount.keychain)
    }
    func existBoltzKey() -> Bool {
        (try? getBoltzKey()) != nil
    }
    public func selectableAssets(subaccounts: [WalletItem]) -> [String]? {
        let hasSubaccountAmp = !subaccounts.filter({ $0.type == .amp }).isEmpty
        let hasLightning = !subaccounts.filter({ $0.networkType.lightning }).isEmpty
        let hasLiquid = !subaccounts.filter({ $0.networkType.liquid }).isEmpty
        let hasBitcoin = !subaccounts.filter({ $0.networkType.bitcoin }).isEmpty
        let assetIds = WalletManager.current?.registry.all
            .filter { !(!hasSubaccountAmp && $0.amp == true) }
            .filter { hasLightning || $0.assetId != AssetInfo.lightningId }
            .filter { hasBitcoin || ![AssetInfo.btcId, AssetInfo.testId].contains($0.assetId) }
            .filter { hasLiquid || [AssetInfo.btcId, AssetInfo.testId, AssetInfo.lightningId].contains($0.assetId) }
            .map { $0.assetId }
        return assetIds
    }

    func assetSelectViewModel(subaccounts: [WalletItem]) -> AssetSelectViewModel {
        let hasSubaccountAmp = !subaccounts.filter({ $0.type == .amp }).isEmpty
        let hasLiquid = !subaccounts.filter({ $0.networkType.liquid }).isEmpty
        let assetIds = selectableAssets(subaccounts: subaccounts)
        let list = AssetAmountList.from(assetIds: assetIds ?? [])
        return AssetSelectViewModel(
            assets: list,
            enableAnyLiquidAsset: hasLiquid,
            enableAnyAmpAsset: hasSubaccountAmp)
    }

    func dialogAccountsViewModel(assetId: String, subaccounts: [WalletItem], hideBalance: Bool = false) -> DialogAccountsViewModel {
        return DialogAccountsViewModel(
            title: "id_account_selector".localized,
            hint: "id_choose_which_account_you_want".localized,
            isSelectable: true,
            assetId: assetId,
            accounts: subaccounts,
            hideBalance: hideBalance)
    }

    func hideBalance(_ value: Bool) async throws {
        try await walletDataModel.hideBalance(value)
    }
}
