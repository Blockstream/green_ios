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
                        filter(for: assetId, subaccount: subaccount)
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

    private func filter(for assetId: String, subaccount: WalletItem) -> Bool {
        switch draft.paymentTarget {
        case .liquidBip21(let liquidBip21):
            return liquidBip21.asset == assetId
        case .lightningInvoice, .lightningOffer, .lnUrl:
            if subaccount.networkType.lightning {
                return assetId == AssetInfo.lightningId
            }
            if subaccount.networkType.liquid {
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
