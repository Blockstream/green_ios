import Foundation
import core
import gdk
import greenaddress
import UIKit

class SendTxConfirmViewModel {

    var transaction: Transaction?
    var subaccount: WalletItem?
    var wm: WalletManager? { WalletManager.current }
    var denominationType: DenominationType
    var isFiat = false
    var session: SessionManager? { subaccount?.session }
    var sendTransaction: SendTransactionSuccess?
    var error: Error?
    var txType: TxType
    
    internal init(transaction: Transaction?, subaccount: WalletItem?, denominationType: DenominationType, isFiat: Bool, txType: TxType) {
        self.transaction = transaction
        self.subaccount = subaccount
        self.denominationType = denominationType
        self.isFiat = isFiat
        self.txType = txType
    }
    
    var isLightning: Bool { subaccount?.networkType == .lightning }
    var isConsolitating: Bool { txType == .redepositExpiredUtxos }
    var hasHW: Bool { wm?.account.isHW ?? false }
    var addressee: Addressee? { transaction?.addressees.first }
    var address: String? { addressee?.address }
    var assetId: String { addressee?.assetId ?? subaccount?.gdkNetwork.getFeeAsset() ?? "btc" }
    var sendAll: Bool { addressee?.isGreedy ?? false}
    var satoshi: Int64? { addressee?.satoshi }
    var asset: AssetInfo? { wm?.info(for: assetId) }
    var isLiquid: Bool { transaction?.subaccountItem?.gdkNetwork.liquid ?? false }
    
    var assetImage: UIImage? {
        if isLightning {
            return UIImage(named: "ic_lightning_btc")
        }
        return wm?.image(for: assetId)
    }

    var note: String? {
        get { transaction?.memo }
        set { transaction?.memo = newValue }
    }
    
    var amount: Balance? { Balance.fromSatoshi(satoshi ?? 0, assetId: assetId) }
    var fee: Balance? { Balance.fromSatoshi(transaction?.fee ?? 0, assetId: transaction?.feeAsset ?? "btc") }
    var total: Balance? {
        let feeAsset = session?.gdkNetwork.getFeeAsset()
        var amount = satoshi ?? 0
        if feeAsset == assetId {
            amount += Int64(transaction?.fee ?? 0)
        }
        return Balance.fromSatoshi(amount, assetId: assetId)
    }
    
    var amountDenomText: String? { amount?.toText(denominationType) }
    var amountFiatText: String? { amount?.toFiatText() }
    var feeDenomText: String? { fee?.toText(denominationType) }
    var feeFiatText: String? { fee?.toFiatText() }
    var totalDenomText: String? { total?.toText(denominationType) }
    var totalFiatText: String? { total?.toFiatText() }
    
    var amountText: String? { isFiat ? amountFiatText : amountDenomText }
    var subamountText: String? { isFiat ? amountDenomText : amountFiatText}
    var feeText: String? { isFiat ? feeFiatText : feeDenomText }
    var totalText: String? { isFiat ? totalFiatText : totalDenomText }
    var conversionText: String? { isFiat ? totalDenomText : totalFiatText }
    var addressTitle: String { isLightning ? "id_recipient" : isConsolitating ? "Your Redeposit Address" : "id_address" }
    var amountTitle: String { isConsolitating ? "Redepositing" : "Recipient Receives" }
    var recipientReceivesHidden: Bool { isConsolitating }

    private func _send() async throws -> SendTransactionSuccess {
        guard let session = session,
              var tx = transaction else {
            throw TransactionError.invalid(localizedDescription: "Invalid transaction")
        }
        if wm?.hwDevice != nil {
            let bleDevice = BleViewModel.shared
            if !bleDevice.isConnected() {
                try await bleDevice.connect()
                _ = try await bleDevice.authenticating()
            }
        }
        if isLiquid {
            tx = try await session.blindTransaction(tx: tx)
        }
        tx = try await session.signTransaction(tx: tx)
        self.transaction = tx
        if tx.isSweep {
            return try await session.broadcastTransaction(txHex: tx.transaction ?? "")
        } else {
            return try await session.sendTransaction(tx: tx)
        }
    }

    func send() async throws -> SendTransactionSuccess {
        AnalyticsManager.shared.startSendTransaction()
        AnalyticsManager.shared.startFailedTransaction()
        let withMemo = !(transaction?.memo?.isEmpty ?? true)
        let transSgmt = AnalyticsManager.TransactionSegmentation(
            transactionType: transaction?.txType ?? .transaction,
            addressInputType: .paste,
            sendAll: sendAll)
        do {
            let res = try await _send()
            sendTransaction = res
            AnalyticsManager.shared.endSendTransaction(
                account: AccountsRepository.shared.current,
                walletItem: subaccount,
                transactionSgmt: transSgmt,
                withMemo: withMemo)
            if sendAll { AnalyticsManager.shared.emptiedAccount = subaccount }
            return res
        } catch {
            AnalyticsManager.shared.failedTransaction(
                account: AccountsRepository.shared.current,
                walletItem: subaccount,
                transactionSgmt: transSgmt,
                withMemo: withMemo,
                prettyError: error.description() ?? "",
                nodeId: wm?.lightningSession?.nodeState?.id
            )
            self.error = error
            throw error
        }
    }

    func sendHWConfirmViewModel() -> SendHWConfirmViewModel {
        SendHWConfirmViewModel(
            isLedger: wm?.account.isLedger ?? false,
            tx: transaction!,
            denomination: denominationType,
            subaccount: self.subaccount)
    }

    func urlForTx() -> URL? {
        return URL(string: (subaccount?.gdkNetwork.txExplorerUrl ?? "") + (sendTransaction?.txHash ?? ""))
    }

    func urlForTxUnblinded() -> URL? {
        return URL(string: (subaccount?.gdkNetwork.txExplorerUrl ?? "") + (sendTransaction?.txHash ?? "") + (transaction?.blindingUrlString(address: address) ?? ""))
    }
}
