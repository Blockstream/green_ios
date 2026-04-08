import Foundation
import gdk

extension Transaction {

    public var subaccount: WalletItem? {
        get { WalletManager.current?.subaccounts.filter({ $0.id == subaccountId }).first }
        set { subaccountId = newValue?.id }
}

    public var feeAsset: String {
        subaccount?.gdkNetwork.getFeeAsset() ?? "btc"
    }

    public var amountsWithFee: [String: Int64] {
        var amounts = amounts
        amounts[feeAsset] = (amounts[feeAsset] ?? 0) - Int64(fee ?? 0)
        return amounts
    }
    public func amountsWithFees() -> [String: Int64] {
        if type == .redeposit {
            return [feeAsset: -1 * Int64(fee ?? 0)]
        } else {
            // remove LBTC asset only if fee on outgoing transactions
            if type == .some(.outgoing) || type == .some(.mixed) {
                return amounts.filter({ !($0.key == feeAsset && abs($0.value) == Int64(fee ?? 0)) })
            }
        }
        return amounts
    }

    public var amountsWithoutFees: [String: Int64] {
        if type == .some(.redeposit) {
            return [:]
        } else if isLiquid {
            // remove LBTC asset only if fee on outgoing transactions
            if type == .some(.outgoing) || type == .some(.mixed) {
                return amounts.filter({ !($0.0 == feeAsset && abs($0.1) == Int64(fee ?? 0)) })
            }
        }
        return amounts
    }

    public var isLightning: Bool {
        self.subaccount?.gdkNetwork.lightning ?? false
    }

    public func isUnconfirmed(block: UInt32) -> Bool {
        if isLightning {
            return isPendingCloseChannel ?? false && blockHeight <= 0
        } else if blockHeight == 0 {
            return true
        } else {
            return false
        }
    }

    public func isPending(block: UInt32) -> Bool {
        if isLightning {
            return isPendingCloseChannel ?? false && (blockHeight <= 0)
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

    public func confirmations(block: UInt32) -> UInt32 {
        if isLightning || blockHeight == 0 {
            return 0
        } else if blockHeight == UInt32.max {
            return blockHeight
        } else if blockHeight <= block {
            return (block - blockHeight) + 1
        } else {
            return 0
        }
    }
}
