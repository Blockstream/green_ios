import Foundation
import UIKit
import core

class CreateAccountViewModel {
    let mainWallet: Wallet
    var wm: WalletManager
    var asset: String?
    var anyLiquidAsset: Bool = false
    var anyLiquidAmpAsset: Bool = false
    var anyLiquidAmpLegacyAsset: Bool = false
    var onlyBtc: Bool = false
    var assetCellModel: AssetSelectCellModel? {
        if anyLiquidAmpAsset {
            return AssetSelectCellModel(anyAmp: true)
        } else if anyLiquidAmpLegacyAsset {
            return AssetSelectCellModel(anyAmpLegacy: true)
        } else if anyLiquidAsset {
            return AssetSelectCellModel(anyLiquid: true)
        } else if let asset = asset {
            return AssetSelectCellModel(assetId: asset, satoshi: 0)
        }
        return nil
    }
    private var service: CreateAccountService {
        CreateAccountService(wm: wm, mainWallet: mainWallet)
    }

    init(
        wm: WalletManager,
        mainWallet: Wallet,
        asset: String? = nil,
         anyLiquidAsset: Bool = false,
         anyLiquidAmpAsset: Bool = false,
         anyLiquidAmpLegacyAsset: Bool = false,
         onlyBtc: Bool = false) {
        self.wm = wm
        self.mainWallet = mainWallet
        self.asset = asset
        self.anyLiquidAsset = anyLiquidAsset
        self.anyLiquidAmpAsset = anyLiquidAmpAsset
        self.anyLiquidAmpLegacyAsset = anyLiquidAmpLegacyAsset
        self.onlyBtc = onlyBtc
    }

    var unarchiveCreateDialog: (( @escaping (Bool) -> Void) -> Void)?
    var isAllPoliciesShown = false

    var isLiquidSelection: Bool {
        anyLiquidAsset || anyLiquidAmpAsset || anyLiquidAmpLegacyAsset || asset != "btc"
    }

    private var supportsLiquidTwoFactor: Bool {
        // Ledger cannot log in to a new Liquid GDK session. An existing Liquid
        // multisig backend means the account-creation flow is already supported.
        return !wm.isLedger || wm.hasLiquidMultisig
    }

    func listBitcoin(extended: Bool) -> [AccountTypeOption] {
        var policies: [AccountTypeOption] = [.NativeSegwit, .TwoOfThreeWith2FA, .TwoFAProtected]
        if extended {
            policies.append(.LegacySegwit)
        }
        return policies
    }

    func listLiquid(extended: Bool) -> [AccountTypeOption] {
        var policies: [AccountTypeOption] = [.NativeSegwit]
        if supportsLiquidTwoFactor {
            policies.append(.TwoFAProtected)
        }
        if extended {
            policies.append(.LegacySegwit)
        }
        return policies
    }

    func isAdvancedEnable() -> Bool {
        if anyLiquidAmpAsset || anyLiquidAmpLegacyAsset { // any amp liquid asset
            return false
        } else if let asset = asset, let asset = WalletManager.current?.info(for: asset), asset.amp ?? false { // amp liquid asset
            return false
        }
        return true
    }

    func resetSelection() {
        anyLiquidAsset = false
        anyLiquidAmpAsset = false
        anyLiquidAmpLegacyAsset = false
    }

    func hasLightning() -> Bool {
        return wm.hasLightning
    }

    func getAccountCellModels() -> [AccountTypeCellModel] {
        let policies = policiesForAsset(extended: isAllPoliciesShown)
        return policies.map { AccountTypeCellModel.from(policy: $0) }
    }

    func policiesForAsset(extended: Bool) -> [AccountTypeOption] {
        if anyLiquidAmpAsset || anyLiquidAmpLegacyAsset { // any amp liquid asset
            return [.Amp]
        } else if anyLiquidAsset { // any liquid asset
            return listLiquid(extended: extended)
        } else if AssetInfo.btcId == asset { // btc
            return listBitcoin(extended: extended)
        } else if let asset = asset, let asset = WalletManager.current?.info(for: asset), asset.amp ?? false { // amp liquid asset
            return [.Amp]
        } else { // liquid
            return listLiquid(extended: extended)
        }
    }

    func needsBluetoothAccess(policy: AccountTypeOption) -> Bool {
        policy.accountType.multisig && mainWallet.isJade && wm.isWatchonly
    }

    func disableBiometric() {
        guard mainWallet.isJade && wm.isWatchonly else {
            return
        }
        _ = AuthenticationTypeHandler
            .removeAuth(
                method: .AuthKeyWoCredentials,
                for: mainWallet.keychain
            )
    }

    func create(policy: AccountTypeOption, params: CreateSubaccountParams) async throws -> SubaccountAction {
        try await service.create(
            policy: policy,
            params: params,
            isLiquid: isLiquidSelection,
            shouldCreateNew: { [weak self] in
                await self?.askCreateOrUnarchive() ?? false
            }
        )
    }

    func uniqueName(_ type: AccountType, liquid: Bool) -> String {
        let network = liquid ? " Liquid " : " "
        let counter = wm.accounts.filter { $0.type == type && $0.gdkNetwork.liquid == liquid }.count
        if counter > 0 {
            return "\(type.string)\(network)\(counter+1)"
        }
        return "\(type.string)\(network)"
    }

    private func askCreateOrUnarchive() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            if let dialog = unarchiveCreateDialog {
                dialog { create in
                    Task { @MainActor in
                        continuation.resume(returning: create)
                    }
                }
            } else {
                Task { @MainActor in
                    continuation.resume(returning: false)
                }
            }
        }
    }
}
