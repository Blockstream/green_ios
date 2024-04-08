import Foundation
import BreezSDK
import gdk

extension Transaction {

    public var subaccountItem: WalletItem? {
        return WalletManager.current?.subaccounts.filter({ $0.hashValue == subaccount }).first
    }
    
    public var feeAsset: String {
        subaccountItem?.gdkNetwork.getFeeAsset() ?? ""
    }

    public func amountsWithFees() -> [String: Int64] {
        if type == .redeposit {
            return [feeAsset: -1 * Int64(fee)]
        } else {
            // remove L-BTC asset only if fee on outgoing transactions
            if type == .some(.outgoing) || type == .some(.mixed) {
                return amounts.filter({ !($0.key == feeAsset && abs($0.value) == Int64(fee)) })
            }
        }
        return amounts
    }
    
    public var amountsWithoutFees: [String: Int64] {
        if type == .some(.redeposit) {
            return [:]
        } else if isLiquid {
            // remove L-BTC asset only if fee on outgoing transactions
            if type == .some(.outgoing) || type == .some(.mixed) {
                return amounts.filter({ !($0.0 == feeAsset && abs($0.1) == Int64(fee)) })
            }
        }
        return amounts
    }

    public var isLightning: Bool {
        self.subaccountItem?.gdkNetwork.lightning ?? false
    }

    public func isUnconfirmed(block: UInt32) -> Bool {
        if isLightning {
            return isPendingCloseChannel ?? false || blockHeight <= 0
        } else if blockHeight == 0 {
            return true
        } else {
            return false
        }
    }

    public func isPending(block: UInt32) -> Bool {
        if isLightning {
            return isPendingCloseChannel ?? false || (blockHeight <= 0)
        } else if blockHeight == 0 || blockHeight == UInt32.max {
            return true
        } else if isLiquid && block < blockHeight + 1 && block >= blockHeight {
            return true
        } else if !isLiquid && block < blockHeight + 5 && block >= blockHeight {
            return true
        } else {
            return false
        }
    }

    public static func fromPayment(_ payment: BreezSDK.Payment, subaccount: Int) -> Transaction {
        var tx = Transaction([:])
        tx.subaccount = subaccount
        tx.blockHeight = UInt32(payment.paymentTime)
        tx.canRBF = false
        tx.memo = payment.description ?? ""
        tx.fee = payment.feeMsat / 1000
        tx.createdAtTs = payment.paymentTime * 1000000
        tx.feeRate = 0
        tx.type = payment.paymentType == .received ? .incoming : .outgoing
        tx.amounts = ["btc": payment.amountSatoshi]
        tx.isLightningSwap = false
        tx.isPendingCloseChannel = payment.paymentType == PaymentType.closedChannel && payment.status == PaymentStatus.pending
        
        switch payment.details {
        case .ln(let data):
            switch data.lnurlSuccessAction {
            case .message(let data):
                tx.message = data.message
            case .aes(let data):
                switch data {
                case .decrypted(let data):
                    tx.plaintext = (data.description, data.plaintext)
                case .errorStatus(let reason):
                    tx.error = reason
                }
            case .url(let data):
                tx.url = (data.description, data.url)
            default:
                break
            }
            tx.paymentHash = data.paymentHash
            tx.destinationPubkey = data.destinationPubkey
            tx.paymentPreimage = data.paymentPreimage
            tx.invoice = data.bolt11
            tx.hash = payment.id
        case .closedChannel(let data):
            tx.hash = data.closingTxid
            tx.closingTxid = data.closingTxid
            tx.fundingTxid = data.fundingTxid
        }
        return tx
    }

    public static func fromSwapInfo(_ swapInfo: SwapInfo, subaccount: Int, isRefundableSwap: Bool) -> Transaction {
        var tx = Transaction([:])
        tx.subaccount = subaccount
        tx.blockHeight = isRefundableSwap ? UInt32.max : 0
        tx.canRBF = false
        tx.memo = nil
        tx.fee = 0
        tx.feeRate = 0
        tx.createdAtTs = swapInfo.createdAt * 1_000_000
        tx.hash = swapInfo.refundTxIds.first
        tx.type = .mixed
        tx.inputs = [["address": swapInfo.bitcoinAddress]]
        tx.outputs = []
        tx.amounts = ["btc": Int64(swapInfo.confirmedSats + swapInfo.unconfirmedSats)]
        tx.isLightningSwap = true
        tx.isInProgressSwap = swapInfo.status != .expired && !isRefundableSwap
        tx.isRefundableSwap = isRefundableSwap
        tx.invoice = swapInfo.bolt11

        return tx
    }
    
    static func fromReverseSwapInfo(_ swapInfo: ReverseSwapInfo, subaccount: Int, isRefundableSwap: Bool) -> Transaction {
        var tx = Transaction([:])
        tx.subaccount = subaccount
        tx.blockHeight = isRefundableSwap ? UInt32.max : 0
        tx.canRBF = false
        tx.memo = ""
        tx.fee = 0
        tx.feeRate = 0
        tx.createdAtTs = isRefundableSwap ? Int64.max : 0
        tx.hash = swapInfo.lockupTxid
        tx.type = .mixed
        tx.inputs = [["address": swapInfo.claimPubkey]]
        tx.outputs = []
        tx.amounts = ["btc": Int64(swapInfo.onchainAmountSat)]
        tx.isLightningSwap = true
        tx.isInProgressSwap = swapInfo.status == .inProgress
        tx.isRefundableSwap = isRefundableSwap
        return tx
    }
}
