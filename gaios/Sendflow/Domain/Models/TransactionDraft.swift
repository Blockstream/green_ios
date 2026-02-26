import core
@preconcurrency import LiquidWalletKit
@preconcurrency import gdk

struct TransactionDraft: Sendable {
    var subaccount: WalletItem?
    let address: String?
    let satoshi: UInt64?
    let assetId: String?
    let sendAll: Bool?
    var paymentTarget: PaymentTarget?
    var lockupResponse: LockupResponse?
    var swapPosition: SwapPositionState?
    var swapPayResponse: PreparePayResponse?

    var network: NetworkSecurityCase? { subaccount?.networkType }

    func update(with new: TransactionDraft) -> TransactionDraft {
        return TransactionDraft(
            subaccount: new.subaccount ?? self.subaccount,
            address: new.address ?? self.address,
            satoshi: new.satoshi ?? self.satoshi,
            assetId: new.assetId ?? self.assetId,
            sendAll: new.sendAll ?? self.sendAll,
            paymentTarget: new.paymentTarget ?? self.paymentTarget,
            lockupResponse: new.lockupResponse ?? self.lockupResponse,
            swapPosition: new.swapPosition ?? self.swapPosition,
            swapPayResponse: new.swapPayResponse ?? self.swapPayResponse)
    }
}
