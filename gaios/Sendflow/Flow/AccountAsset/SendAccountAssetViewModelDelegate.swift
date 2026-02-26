import Foundation
import gdk

protocol SendAccountAssetViewModelDelegate: AnyObject {
    @MainActor
    func didSelectAccountAsset(_ vm: SendAccountAssetViewModel, subaccount: WalletItem, assetId: String?)
    @MainActor
    func didSelectAccountAsset(_ vm: SendAccountAssetViewModel, didFailWith error: Error)
}
