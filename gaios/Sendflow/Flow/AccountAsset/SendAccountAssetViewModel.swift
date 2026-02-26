import Foundation
import UIKit
import core
import gdk
import greenaddress

@MainActor
class SendAccountAssetViewModel {

    let subaccounts: [WalletItem]
    let draft: TransactionDraft
    var cellModels: [AccountAssetCellModel] = []
    let wallet: WalletManager
    let delegate: SendAccountAssetViewModelDelegate?

    init(subaccounts: [WalletItem], draft: TransactionDraft, wallet: WalletManager, delegate: SendAccountAssetViewModelDelegate) {
        self.draft = draft
        self.subaccounts = subaccounts
        self.wallet = wallet
        self.delegate = delegate
        self.cellModels = getCellModels()
    }

    func getCellModels() -> [AccountAssetCellModel] {
        return subaccounts
            .flatMap { subaccount in
                (subaccount.satoshi ?? [:])
                    .filter { assetId, _ in
                        filter(for: assetId)
                    }.compactMap { assetId, amount in
                        AccountAssetCellModel(
                            account: subaccount,
                            asset: wallet.info(for: assetId),
                            assetIcon: wallet.image(for: assetId),
                            balance: amount,
                            showBalance: true
                        )
                    }
            }
            .sorted()
    }

    private func filter(for assetId: String) -> Bool {
        switch draft.paymentTarget {
        case .liquidBip21(let liquidBip21):
            return liquidBip21.asset == assetId
        case .lightningInvoice:
            return AssetInfo.baseIds.contains(assetId)
        default:
            return true
        }
    }

    func select(cell: AccountAssetCellModel) {
        delegate?.didSelectAccountAsset(self, subaccount: cell.account, assetId: cell.asset.assetId)
    }
}
