import core
import CoreData
@preconcurrency import LiquidWalletKit
@preconcurrency import gdk

struct TransactionDraft: Sendable {
    var subaccount: WalletItem?
    let address: String?
    var satoshi: UInt64?
    let assetId: String?
    var sendAll: Bool?
    var paymentTarget: PaymentTarget?
    var lockupResponse: LockupResponse?
    var swapPosition: SwapPositionState?
    var swapPayResponse: PreparePayResponse?
    var persistentId: NSManagedObjectID?
    // Original ₿-prefixed BIP-353 input. Preserved across routing so the review
    // screen can show the human-readable address even after we replace the
    // payment target with the resolved BOLT12/BIP-21/BOLT11 target.
    var bip353Origin: String?

    var network: NetworkSecurityCase? { subaccount?.networkType }

    var isSubmarineSwap: Bool { lockupResponse != nil }
    var isCrossChainSwap: Bool { swapPosition != nil && swapPayResponse != nil }

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
            swapPayResponse: new.swapPayResponse ?? self.swapPayResponse,
            persistentId: new.persistentId ?? self.persistentId,
            bip353Origin: new.bip353Origin ?? self.bip353Origin)
    }
}
