import Foundation
import UIKit
import core

import greenaddress

@MainActor
class SendAccountAssetViewModel {

    let subaccounts: [Account]
    let draft: TransactionDraft
    var cellModels: [AccountAssetCellModel] = []
    let wm: WalletManager
    let delegate: SendAccountAssetViewModelDelegate?

    init(subaccounts: [Account], draft: TransactionDraft, wm: WalletManager, delegate: SendAccountAssetViewModelDelegate) {
        self.draft = draft
        self.subaccounts = subaccounts
        self.wm = wm
        self.delegate = delegate
        self.cellModels = getCellModels()
    }

    func getCellModels() -> [AccountAssetCellModel] {
        return subaccounts
            .flatMap { subaccount in
                wm.accountBackendOrNil(subaccount)?
                    .assets
                    .filter { assetId, _ in
                        filter(for: assetId, subaccount: subaccount)
                    }.compactMap { assetId, amount in
                        AccountAssetCellModel(
                            account: subaccount,
                            asset: wm.info(for: assetId),
                            assetIcon: wm.image(for: assetId),
                            balance: amount,
                            showBalance: true
                        )
                    } ?? []
            }
            .sorted()
    }

    private func filter(for assetId: String, subaccount: Account) -> Bool {
        switch draft.paymentTarget {
        case .liquidBip21(let liquidBip21):
            return liquidBip21.asset == assetId
        case .lightningInvoice, .lightningOffer, .lnUrl:
            if subaccount.networkId.lightning {
                return assetId == AssetInfo.lightningId
            }
            if subaccount.networkId.liquid {
                // For lightning-destination flows on Liquid, only allow paying with fee asset (LBTC).
                return assetId == subaccount.gdkNetwork.getFeeAsset()
            }
            return false
        default:
            return true
        }
    }

    func select(cell: AccountAssetCellModel) {
        delegate?.didSelectAccountAsset(self, subaccount: cell.account, assetId: cell.asset.assetId)
    }
}
