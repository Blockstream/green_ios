import Foundation
import core

protocol SendAccountAssetViewModelDelegate: AnyObject {
    @MainActor
    func didSelectAccountAsset(_ vm: SendAccountAssetViewModel, subaccount: Account, assetId: String?)
    @MainActor
    func didSelectAccountAsset(_ vm: SendAccountAssetViewModel, didFailWith error: Error)
}
