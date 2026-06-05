import Foundation
import gdk

protocol ReceiveViewModelDelegate: AnyObject {
    @MainActor
    func editNote(vm: ReceiveViewModel, description: String)
    @MainActor
    func fundingFee()
    @MainActor
    func denominationSelector(vm: ReceiveViewModel, model: DialogInputDenominationViewModel)
    @MainActor
    func invoice(_ model: LNInvoiceViewModel)
    @MainActor
    func addressAuth(_ model: AddressAuthViewModel)
    @MainActor
    func manualBackup(_ model: ManualBackupViewModel)
    @MainActor
    func send(subaccount: WalletItem, anyOrAsset: AnyOrAsset)
}
