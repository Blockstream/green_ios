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
    var isJade: Bool { wm?.account.isJade ?? false }
    var session: SessionManager? {
        guard let subaccount = subaccount else { return nil }
        if isJade && BleHwManager.shared.walletManager != nil {
            if BleHwManager.shared.isConnected() {
                return BleHwManager.shared.walletManager?.getSession(for: subaccount)
            }
        }
        return WalletManager.current?.getSession(for: subaccount)
    }
    var sendTransaction: SendTransactionSuccess?
    var error: Error?
    var txType: TxType
    var unsignedPsbt: String?
    var signedPsbt: String?
    var bcurUnsignedPsbt: BcurEncodedData?
    var importSignedPsbt = false
    var isWithdraw: Bool { withdrawData != nil }
    var withdrawData: LnUrlWithdrawRequestData?
    var hasWithdrawNote: Bool { withdrawNote != nil && withdrawNote != "" }
    var withdrawNote: String? {
        guard let withdrawData = withdrawData else { return nil }
        return withdrawData.defaultDescription
    }
    var withdrawAmount: UInt64 = 0
    var txAddresses: [Address]? {
        transaction?.addressees.compactMap { Address(address: $0.address, subtype: $0.subtype, userPath: $0.userPath, isGreedy: $0.isGreedy) }
    }

    internal init(transaction: Transaction?, subaccount: WalletItem?, denominationType: DenominationType, isFiat: Bool, txType: TxType, unsignedPsbt: String?, signedPsbt: String?) {
        self.transaction = transaction
        self.subaccount = subaccount
        self.denominationType = denominationType
        self.isFiat = isFiat
        self.txType = txType
        self.verifyAddressState = (txType == .redepositExpiredUtxos && (WalletManager.current?.account.isHW ?? false) && !(subaccount?.session?.networkType.liquid ?? false)) ? .unverified : .noneed
        self.unsignedPsbt = unsignedPsbt
        self.signedPsbt = signedPsbt
        self.importSignedPsbt = signedPsbt != nil
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
    var isLiquid: Bool { transaction?.subaccount?.gdkNetwork.liquid ?? false }

    var assetImage: UIImage? {
        if multiAddressees {
            return wm?.image(for: transaction?.feeAsset ?? "btc")
        }
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

    var multiAddressees: Bool {
        if txType != .redepositExpiredUtxos {
            return false
        }
        return (transaction?.addressees.count ?? 0) > 1 ? true : false
    }
    func getAssetIcons() -> [UIImage] {
        transaction?.addressees.compactMap { $0.assetId }.compactMap { self.wm?.image(for: $0) } ?? []
    }
    func enableExportPsbt() -> Bool {
        wm?.isWatchonly ?? false && session?.networkType.singlesig ?? false && txType != .sweep && !importSignedPsbt
    }
    func needConnectHw() -> Bool {
        wm?.account.isHW ?? false
    }
    func needExportPsbt() -> Bool {
        wm?.isWatchonly ?? false && session?.networkType.singlesig ?? false && txType != .sweep && signedPsbt == nil
    }
    private func sendTx() async throws -> SendTransactionSuccess {
        guard let session = session,
              var tx = transaction else {
            throw TransactionError.invalid(localizedDescription: "Invalid transaction")
        }
        if let error = tx.error {
            throw TransactionError.invalid(localizedDescription: error)
        }
        if isLiquid {
            tx = try await session.blindTransaction(tx: tx)
        }
        tx = try await session.signTransaction(tx: tx)
        if let error = tx.error {
            throw TransactionError.invalid(localizedDescription: error)
        }
        self.transaction = tx
        if tx.isSweep {
            return try await session.broadcastTransaction(BroadcastTransactionParams(transaction: tx.transaction))
        } else {
            return try await session.sendTransaction(tx: tx)
        }
    }

    func exportPsbt() async throws {
        guard let session = session,
              let tx = transaction else {
            throw TransactionError.invalid(localizedDescription: "Invalid transaction")
        }
        unsignedPsbt = try await session.getPsbt(tx: tx)
        let params = BcurEncodeParams(urType: "crypto-psbt", data: unsignedPsbt)
        guard let res = try await session.bcurEncode(params: params) else {
            throw TransactionError.invalid(localizedDescription: "Invalid bcur")
        }
        bcurUnsignedPsbt = res
    }

    func sendPsbt() async throws -> SendTransactionSuccess {
        guard let session = session else {
            throw TransactionError.invalid(localizedDescription: "Invalid session")
        }
        guard let psbt = signedPsbt else {
            throw TransactionError.invalid(localizedDescription: "Invalid psbt")
        }
        return try await session.broadcastTransaction(BroadcastTransactionParams(psbt: psbt, memo: transaction?.memo, simulateOnly: false))
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
            if signedPsbt != nil {
                sendTransaction = try await sendPsbt()
            } else {
                sendTransaction = try await sendTx()
            }
            AnalyticsManager.shared.endSendTransaction(
                account: AccountsRepository.shared.current,
                walletItem: subaccount,
                transactionSgmt: transSgmt,
                withMemo: withMemo)
            if sendAll { AnalyticsManager.shared.emptiedAccount = subaccount }
            return sendTransaction!
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
            subaccount: self.subaccount,
            isMultiAddressees: self.multiAddressees)
    }

    func tempSendHWConfirmViewModel() -> SendHWConfirmViewModel {
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

    func validateHW(_ address: Address) async throws -> Bool {
        guard let subaccount = subaccount else {
            throw GaError.GenericError("Invalid subaccount".localized)
        }
        return try await BleHwManager.shared.validateAddress(account: subaccount, address: address)
    }

    func sendVerifyOnDeviceViewModel(_ address: Address) -> HWDialogVerifyOnDeviceViewModel? {
        guard let address = address.address else { return nil }
        let account = AccountsRepository.shared.current
        return HWDialogVerifyOnDeviceViewModel(isLedger: account?.isLedger ?? false,
                                       address: address,
                                       isRedeposit: true,
                                       isDismissible: false)
    }

    func showSignTransactionViaQR() -> Bool {
        wm?.isWatchonly ?? false && [.bitcoinSS, .testnetSS].contains(session?.networkType) && txType != .sweep && !importSignedPsbt
    }

    func showSignTransaction() -> Bool {
        !(wm?.isWatchonly ?? false) || (wm?.isHW ?? false) || importSignedPsbt
    }
}
