import UIKit

import core

@MainActor
protocol TransactActionsDataSource: AnyObject {
    var walletDataModel: WalletDataModel { get }
    var wm: WalletManager { get }
    var mainWallet: Wallet { get }
    var subaccounts: [Account]? { get }
    var hideBalance: Bool { get }
    var defaultCurrency: String? { get }

    func assetSelectViewModel(subaccounts: [Account]) -> AssetSelectViewModel
    func dialogAccountsViewModel(assetId: String, subaccounts: [Account], hideBalance: Bool) -> DialogAccountsViewModel
    func existBoltzKey() -> Bool
    func canSwap() -> Bool
}

extension TransactActionsDataSource {
    func getBoltzKey() throws -> Credentials {
        try AuthenticationTypeHandler.getCredentials(method: .AuthKeyBoltz, for: mainWallet.keychain)
    }

    func existBoltzKey() -> Bool {
        (try? getBoltzKey()) != nil
    }

    func selectableAssets(subaccounts: [Account]) -> [String]? {
        let hasSubaccountAmp = !subaccounts.filter(
            { $0.type == .ampAccount || $0.type == .amp2Account
            }).isEmpty
        let hasLightning = !subaccounts.filter({ $0.networkId.lightning }).isEmpty
        let hasLiquid = !subaccounts.filter({ $0.networkId.liquid }).isEmpty
        let hasBitcoin = !subaccounts.filter({ $0.networkId.bitcoin }).isEmpty
        let assetIds = wm.registry.all
            .filter { !(!hasSubaccountAmp && $0.amp == true) }
            .filter { hasLightning || $0.assetId != AssetInfo.lightningId }
            .filter { hasBitcoin || ![AssetInfo.btcId, AssetInfo.testId].contains($0.assetId) }
            .filter { hasLiquid || [AssetInfo.btcId, AssetInfo.testId, AssetInfo.lightningId].contains($0.assetId) }
            .map { $0.assetId }
        return assetIds
    }

    func assetSelectViewModel(subaccounts: [Account]) -> AssetSelectViewModel {
        let hasSubaccountAmp = !subaccounts.filter({ $0.type == .amp2Account }).isEmpty
        let hasSubaccountAmpLegacy = !subaccounts.filter({ $0.type == .ampAccount }).isEmpty
        let hasLiquid = !subaccounts.filter({ $0.networkId.liquid }).isEmpty
        let assetIds = selectableAssets(subaccounts: subaccounts)
        let list = AssetAmountList.from(assetIds: assetIds ?? [])
        return AssetSelectViewModel(
            assets: list,
            enableAnyLiquidAsset: hasLiquid,
            enableAnyAmpAsset: hasSubaccountAmp,
            enableAnyAmpLegacyAsset: hasSubaccountAmpLegacy)
    }

    func dialogAccountsViewModel(assetId: String, subaccounts: [Account], hideBalance: Bool = false) -> DialogAccountsViewModel {
        return DialogAccountsViewModel(
            title: "id_account_selector".localized,
            hint: "id_choose_which_account_you_want".localized,
            isSelectable: true,
            assetId: assetId,
            accounts: subaccounts,
            hideBalance: hideBalance)
    }

    func canSwap() -> Bool {
        if mainWallet.isWatchonly || (mainWallet.isHW && mainWallet.boardType == .v2c) {
            return false
        }
        return true
    }

    func getLiquidSubaccounts() -> [Account] {
        wm.liquidSubaccounts.sorted()
    }

    func getLiquidAmpSubaccounts() -> [Account] {
        wm.liquidAmpSubaccounts.sorted()
    }

    func getLiquidAmpLegacySubaccounts() -> [Account] {
        wm.liquidAmpLegacySubaccounts.sorted()
    }

    func getLightningSubaccounts() -> [Account] {
        if let backend = wm.glNetworkBackendOrNil(), backend.isLoggedIn {
            return [backend.account]
        }
        return []
    }

    func getBitcoinSubaccounts() -> [Account] {
        wm.bitcoinSubaccounts.sorted()
    }

    func getAccounts(_ ref: AnyOrAsset) -> [Account] {
        switch ref {
        case .anyLiquid:
            return getLiquidSubaccounts()
        case .anyAmp:
            return getLiquidAmpSubaccounts()
        case .anyAmpLegacy:
            return getLiquidAmpLegacySubaccounts()
        case .asset(let assetId):
            let asset = wm.info(for: assetId)
            if asset.isLightning {
                return getLightningSubaccounts()
            } else if asset.isBitcoin {
                return getBitcoinSubaccounts()
            } else if asset.amp ?? false {
                return getLiquidAmpLegacySubaccounts()
            }
            return getLiquidSubaccounts()
        }
    }
}

@MainActor
final class TransactActionsCoordinator: NSObject {
    private weak var viewController: TabViewController?
    private let dataSource: TransactActionsDataSource

    private var activeSendCoordinator: SendCoordinator?
    private var activeReceiveCoordinator: ReceiveCoordinator?
    private var anyOrAsset: AnyOrAsset?

    init(viewController: TabViewController, dataSource: TransactActionsDataSource) {
        self.viewController = viewController
        self.dataSource = dataSource
    }

    func buy() {
        viewController?.buyScreen(currency: dataSource.defaultCurrency ?? "USD", hideBalance: dataSource.hideBalance)
    }

    func send(input: String? = nil) {
        guard let nav = viewController?.navigationController else { return }
        activeSendCoordinator = SendCoordinator(nav: nav, wallet: dataSource.walletDataModel, mainWallet: dataSource.mainWallet) { [weak self, weak nav] in
            nav?.popToRootViewController(animated: true)
            self?.activeSendCoordinator = nil
        }
        activeSendCoordinator?.start(input: input, subaccount: nil, assetId: nil)
    }

    func receive() {
        pushAssetSelectViewController()
    }

    func swap() {
        AnalyticsManager.shared.swapEntry(wallet: WalletsStorage.shared.current)
        if dataSource.mainWallet.isJade && !dataSource.existBoltzKey() {
            presentJadeSwapDialog()
        } else {
            startSwap()
        }
    }

    private func pushAssetSelectViewController() {
        let storyboard = UIStoryboard(name: "Utility", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AssetSelectViewController") as? AssetSelectViewController {
            vc.viewModel = dataSource.assetSelectViewModel(subaccounts: dataSource.subaccounts ?? [])
            vc.dismissOnSelect = false
            vc.delegate = self
            viewController?.navigationController?.pushViewController(vc, animated: true)
        }
    }

    private func accountsScreen(assetId: String, subaccounts: [Account]) {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        let model = dataSource.dialogAccountsViewModel(assetId: assetId, subaccounts: subaccounts, hideBalance: dataSource.hideBalance)
        let vc = storyboard.instantiateViewController(identifier: "DialogAccountsViewController") { coder in
            DialogAccountsViewController(coder: coder, viewModel: model)
        }
        vc.delegate = self
        vc.modalPresentationStyle = .overFullScreen
        viewController?.present(vc, animated: false, completion: nil)
    }

    private func presentJadeSwapDialog() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "DialogSwapJadeViewController") { coder in
            DialogSwapJadeViewController(coder: coder)
        }
        vc.delegate = self
        vc.modalPresentationStyle = .overFullScreen
        viewController?.present(vc, animated: false, completion: nil)
    }

    private func pushJadeBoltzExportViewController() {
        let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
        let exportViewModel = JadeBoltzExportViewModel(wm: dataSource.wm, mainWallet: dataSource.mainWallet)
        let vc = storyboard.instantiateViewController(identifier: "JadeBoltzExportViewController") { coder in
            JadeBoltzExportViewController(coder: coder, viewModel: exportViewModel)
        }
        vc.delegate = self
        viewController?.navigationController?.pushViewController(vc, animated: false)
    }

    private func startSwap() {
        guard let nav = viewController?.navigationController else { return }
        activeSendCoordinator = SendCoordinator(nav: nav, wallet: dataSource.walletDataModel, mainWallet: dataSource.mainWallet) { [weak self, weak nav] in
            nav?.popToRootViewController(animated: true)
            self?.activeSendCoordinator = nil
        }
        activeSendCoordinator?.startSwap(subaccount: nil, assetId: nil)
    }

    private func handleSelectedAnyOrAsset(_ ref: AnyOrAsset) {
        anyOrAsset = ref
        let accounts = dataSource.getAccounts(ref)
        if accounts.count == 0 {
            DropAlert().warning(message: "Create an account".localized)
        } else if accounts.count == 1 {
            didSelectAccount(accounts.first)
        } else {
            accountsScreen(assetId: ref.assetId, subaccounts: accounts)
        }
    }
}

extension TransactActionsCoordinator: AssetSelectViewControllerDelegate {
    nonisolated func didSelectAnyOrAsset(_ ref: AnyOrAsset) {
        Task { @MainActor [weak self] in
            self?.handleSelectedAnyOrAsset(ref)
        }
    }
}

extension TransactActionsCoordinator: DialogAccountsViewControllerDelegate {
    func didSelectAccount(_ walletItem: Account?) {
        guard let nav = viewController?.navigationController, let account = walletItem, let anyOrAsset else { return }
        activeReceiveCoordinator = ReceiveCoordinator(nav: nav, wallet: dataSource.walletDataModel, mainWallet: dataSource.mainWallet) { [weak self] in
            self?.activeReceiveCoordinator = nil
        }
        activeReceiveCoordinator?.start(account: account, anyOrAsset: anyOrAsset)
    }
}

extension TransactActionsCoordinator: DialogSwapJadeViewControllerDelegate {
    nonisolated func didDismiss() {}

    nonisolated func didEnable() {
        Task { @MainActor [weak self] in
            self?.pushJadeBoltzExportViewController()
        }
    }

    nonisolated func didSelectNotNow() {}
}

extension TransactActionsCoordinator: JadeBoltzExportViewControllerDelegate {
    nonisolated func onExportSucceed() {
        Task { @MainActor [weak self] in
            self?.viewController?.navigationController?.popToRootViewController(animated: true)
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) { [weak self] in
                self?.swap()
            }
        }
    }
}
