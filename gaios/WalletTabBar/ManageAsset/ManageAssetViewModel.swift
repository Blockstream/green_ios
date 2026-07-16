import Foundation
import UIKit

import greenaddress
import hw
import core
import AsyncAlgorithms

class ManageAssetViewModel {

    let walletDataModel: WalletDataModel
    let wm: WalletManager
    var mainWallet: Wallet
    var assetId: String
    var selectedSubaccount: Account?

    var state = WalletState()
    var onUpdate: ((RefreshFeature?) -> Void)?
    var observationTask: Task<Void, Never>?
    var isBTCAsset: Bool {
        "BTC" == assetId.uppercased()
    }
    var selectedAccountBackend: AccountBackend? {
        if let selectedSubaccount {
            return wm.accountBackendOrNil(selectedSubaccount)
        }
        return nil
    }
    var subaccounts: [Account] {
        if assetId == AssetInfo.lightningId {
            return state.subaccounts
            .filter { $0.networkId.lightning && !$0.hidden }
                .sorted()
        } else if assetId == AssetInfo.btcId || assetId == AssetInfo.testId {
            return state.subaccounts.filter { $0.networkId.bitcoin && !$0.hidden }.sorted()
        } else if assetId == AssetInfo.lbtcId || assetId == AssetInfo.ltestId {
            return state.subaccounts.filter { $0.networkId.liquid && !$0.hidden }.sorted()
        } else {
            return state.subaccounts.filter { $0.networkId.liquid && !$0.hidden }.sorted()
        }
    }
    func getBoltzKey() throws -> Credentials {
        try AuthenticationTypeHandler.getCredentials(method: .AuthKeyBoltz, for: mainWallet.keychain)
    }
    func existBoltzKey() -> Bool {
        (try? getBoltzKey()) != nil
    }
    var hideBalance: Bool {
        state.hideBalance
    }
    var balances: [String: Int64]? {
        state.balances
    }
    var selectedBalances: [String: Int64]? {
        guard let selectedSubaccount else {
            return nil
        }
        return state.balancesForSubaccount?[selectedSubaccount.id]
    }
    var totals: (String, Int64)? {
        state.totals
    }
    var assetAmountList: AssetAmountList? {
        state.assetAmountList
    }
    var txs: [Transaction]? {
        if let selectedSubaccount {
            return state.nestedTxs[selectedSubaccount.id]?[assetId]
        }
        return nil
    }
    var actions: [ActionCardType] {
        if assetId == AssetInfo.lightningId && hasOnchainFunds() {
            return [.lightningTransfer]
        }
        return []
    }

    init(walletDataModel: WalletDataModel, wm: WalletManager, mainWallet: Wallet, assetId: String, selectedSubaccount: Account?) {
        self.walletDataModel = walletDataModel
        self.wm = wm
        self.mainWallet = mainWallet
        self.assetId = assetId
        self.selectedSubaccount = selectedSubaccount
        observationTask = Task { [weak self] in
            await self?.startObserving()
        }
    }

    private func startObserving() async {
        for await update in await walletDataModel.states() {
            guard !Task.isCancelled else { break }
            await MainActor.run { [weak self] in
                self?.state = update.state
                self?.onUpdate?(update.feature)
                switch update.feature {
                case .txs:
                    if let selectedSubaccount = self?.selectedSubaccount, let assetId = self?.assetId {
                        Task { [weak self] in
                            await self?.walletDataModel.triggerRefresh(features: [.nestedTxs(subaccount: selectedSubaccount.id, assetId: assetId)])
                        }
                    }
                case .subaccounts:
                    if let currentSubaccountId = self?.selectedSubaccount?.id {
                        self?.selectedSubaccount = self?.subaccounts.first(where: { $0.id == currentSubaccountId })
                    }
                    if self?.selectedSubaccount == nil && self?.subaccounts.count == 1 {
                        self?.selectedSubaccount = self?.subaccounts.first
                    }
                default:
                    break
                }
            }
        }
    }

    deinit {
        observationTask?.cancel()
    }

    func refresh() {
        Task { [weak self] in
            guard let self else { return }
            if let selectedSubaccount {
                await walletDataModel.triggerRefresh(features: [.subaccounts])
                await walletDataModel.triggerRefresh(features: [.balance, .nestedTxs(subaccount: selectedSubaccount.id, assetId: assetId)])
            } else {
                await walletDataModel.triggerRefresh(features: [.subaccounts])
                await walletDataModel.triggerRefresh(features: [.balance])
            }
        }
    }

    func renameSubaccount(name: String) async throws {
        guard let selectedSubaccount else { return }
        self.selectedSubaccount = try await wm.updateAccount(
            account: selectedSubaccount,
            newAccountName: name)
        _ = try await wm.getAccounts()
    }
    func archiveSubaccount() async throws {
        guard let selectedSubaccount else { return }
        self.selectedSubaccount = try await wm.updateAccount(
            account: selectedSubaccount,
            isHidden: true)
        _ = try await wm.getAccounts()
    }
    var isFunded: Bool? {
        return balances?[assetId] ?? 0 > 0
    }
    func hasLightning() -> Bool {
        guard let wallet = WalletsStorage.shared.current else {
            return false
        }
        return AuthenticationTypeHandler.findAuth(
            method: .AuthKeyLightning,
            forNetwork: wallet.keychainLightning)
    }

    func canSendLightning() -> Bool {
        return (
            wm.lightningSession?
                .nodeState()?.channelsBalanceMsat.satoshi ?? 0
        ) > 0
    }
    func hasOnchainFunds() -> Bool {
        return (
            wm.lightningSession?
                .nodeState()?.onchainBalanceMsat.satoshi ?? 0
        ) > 0
    }
    func currency() -> String? {
        wm.prominentSession.settings?.pricing["currency"]
    }
    func canSwap() -> Bool {
        if mainWallet.isWatchonly ||
            (mainWallet.isHW && mainWallet.boardType == .v2c ||
             !AssetInfo.baseIds.contains(assetId) || assetId == AssetInfo.lightningId) {
            return false
        }
        return true
    }

    func lTSettingsDialogViewModel() -> LTSettingsDialogViewModel? {
        guard let lightningSession = wm.lightningSession else { return nil }
        return LTSettingsDialogViewModel(
            mainWallet: mainWallet,
            wallet: walletDataModel,
            lightningSession: lightningSession)
    }

    func lTCreateViewModel() -> LTCreateViewModel? {
        return LTCreateViewModel(
            mainWallet: mainWallet,
            wallet: walletDataModel)
    }
}
