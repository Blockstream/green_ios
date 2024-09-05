import Foundation
import core
import gdk
import greenaddress
import UIKit
import BreezSDK

enum VerifyAddressState {
    case noneed
    case unverified
    case verified
}

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
    var txAddress: Address?
    
    var isWithdraw: Bool {
        return withdrawData != nil
    }
    var withdrawData: LnUrlWithdrawRequestData?
    var hasWithdrawNote: Bool {
        return withdrawNote != nil && withdrawNote != ""
    }
    var withdrawNote: String? {
        guard let withdrawData = withdrawData else { return nil }
        return withdrawData.defaultDescription
    }
    var withdrawAmount: UInt64 = 0

    internal init(transaction: Transaction?, subaccount: WalletItem?, denominationType: DenominationType, isFiat: Bool, txType: TxType, txAddress: Address?) {
        self.transaction = transaction
        self.subaccount = subaccount
        self.denominationType = denominationType
        self.isFiat = isFiat
        self.txType = txType
        self.txAddress = txAddress
        self.verifyAddressState = txType == .redepositExpiredUtxos && (WalletManager.current?.account.isHW ?? false) ? .unverified : .noneed
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
        get { isWithdraw ? withdrawNote : transaction?.memo }
        set { transaction?.memo = newValue }
    }

    var amount: Balance? { Balance.fromSatoshi( isWithdraw ? withdrawAmount : satoshi ?? 0, assetId: assetId) }
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
    var amountTitle: String { isWithdraw ? "id_amount_to_receive" : isConsolitating ? "Redepositing" : "Recipient Receives" }
    var recipientReceivesHidden: Bool { isConsolitating }
    var verifyAddressState: VerifyAddressState

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
    
    func withdrawLnurl(desc: String) async throws -> LnUrlWithdrawSuccessData? {
        guard let withdrawData = withdrawData else { 
            throw TransactionError.failure(localizedDescription: "No data found", paymentHash: "")
        }
        let res = try wm?.lightningSession?.lightBridge?.withdrawLnurl(requestData: withdrawData, amount: withdrawAmount, description: desc)
        switch res {
        case .errorStatus(let data):
            throw TransactionError.failure(localizedDescription: data.reason.localized, paymentHash: "")
        case .timeout(let data):
            throw TransactionError.failure(localizedDescription: "Timeout", paymentHash: "")
        case .ok(let data):
            return data
        case .none:
            throw TransactionError.failure(localizedDescription: "No data found", paymentHash: "")
        }
    }
    
    func validateHW() async throws -> Bool {
        guard let subaccount = subaccount, let address = txAddress else {
            throw GaError.GenericError("Invalid address".localized)
        }
        return try await BleViewModel.shared.validateAddress(account: subaccount, address: address)
    }

    func sendVerifyOnDeviceViewModel() -> VerifyOnDeviceViewModel? {
        guard let _ = subaccount, let address = txAddress?.address else { return nil }
        let account = AccountsRepository.shared.current
        return VerifyOnDeviceViewModel(isLedger: account?.isLedger ?? false, 
                                       address: address,
                                       isRedeposit: true,
                                       isDismissible: false)
    }
}
