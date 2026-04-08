import Foundation
import core
import gdk
import greenaddress
import UIKit
import LiquidWalletKit

enum VerifyAddressState {
    case noneed
    case unverified
    case verified
}

class SendTxConfirmViewModel {

    var transaction: gdk.Transaction?
    var subaccount: WalletItem?
    var wm: WalletManager? { WalletManager.current }
    var mainAccount: Account? { AccountsRepository.shared.current }
    var denominationType: DenominationType
    var isFiat = false
    var isJade: Bool { mainAccount?.isJade ?? false }
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
    var txAddresses: [gdk.Address]? {
        transaction?.addressees.compactMap { Address(address: $0.address, subtype: $0.subtype, userPath: $0.userPath, isGreedy: $0.isGreedy) }
    }
    var pay: PreparePayResponse?

    internal init(transaction: gdk.Transaction?, subaccount: WalletItem?, denominationType: DenominationType, isFiat: Bool, txType: TxType, unsignedPsbt: String?, signedPsbt: String?) {
        self.transaction = transaction
        self.subaccount = subaccount
        self.denominationType = denominationType
        self.isFiat = isFiat
        self.txType = txType
        self.unsignedPsbt = unsignedPsbt
        self.signedPsbt = signedPsbt
        self.importSignedPsbt = signedPsbt != nil
        self.verifyAddressState = (txType == .redepositExpiredUtxos && (AccountsRepository.shared.current?.isHW ?? false) && !(subaccount?.session?.networkType.liquid ?? false)) ? .unverified : .noneed
    }

    var isLightning: Bool { subaccount?.networkType == .lightning }
    var isConsolitating: Bool { txType == .redepositExpiredUtxos }
    var hasHW: Bool { mainAccount?.isHW ?? false }
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
        get { transaction?.memo }
        set { transaction?.memo = newValue }
    }

    var amount: Balance? { Balance.fromSatoshi(Int64(satoshi ?? 0), assetId: assetId) }
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
    var subamountText: String? { isFiat ? amountDenomText : "≈ \(amountFiatText ?? "")"}
    var feeText: String? { isFiat ? "≈ \(feeFiatText ?? "")" : feeDenomText }
    var feeConvertText: String? { !isFiat ? "≈ \(feeFiatText ?? "")" : feeDenomText }
    var totalText: String? { isFiat ? "≈ \(totalFiatText ?? "")" : totalDenomText }
    var conversionText: String? { isFiat ? totalDenomText : "≈ \(totalFiatText ?? "")" }
    var addressTitle: String { isLightning ? "id_recipient".localized : isConsolitating ? "id_your_redeposit_address".localized : "id_address".localized }
    var amountTitle: String { isConsolitating ? "id_redepositing".localized : "id_recipient_receives".localized }
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
        mainAccount?.isHW ?? false
    }
    func needExportPsbt() -> Bool {
        wm?.isWatchonly ?? false && session?.networkType.singlesig ?? false && txType != .sweep && signedPsbt == nil
    }
    var hasPrice: Bool {
        let fiat = Balance.fromSatoshi(Int64(0), assetId: assetId)?.toFiat().0
        if (fiat ?? "").isEmpty {
            return false
        }
        return true
    }
    var isAssetWithPrice: Bool {
        !AssetInfo.baseIds.contains(assetId) && hasPrice
    }
    var totalFiatForPricedAsset: String {
        if let balance = Balance.fromSatoshi(Int64(satoshi ?? 0), assetId: assetId),
           let amount = Decimal(string: (balance.fiat ?? ""), locale: ConverterManager.enUSLocale), let feeBalance =  Balance.fromSatoshi(transaction?.fee ?? 0, assetId: transaction?.feeAsset ?? "btc"),
           let fee = Decimal(string: feeBalance.fiat ?? "", locale: ConverterManager.enUSLocale), let feeCurr = feeBalance.fiatCurrency {
            let totalFiat = amount + fee
            let converter = WalletManager.current?.converter
            if let result = converter?.formatFiat(value: totalFiat, currency: feeCurr, withGroupSeparator: true) {
                return "≈ " + result
            }
        }
        return ""
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
            throw TransactionError.invalid(localizedDescription: "id_invalid_session".localized)
        }
        guard let psbt = signedPsbt else {
            throw TransactionError.invalid(localizedDescription: "id_invalid_psbt".localized)
        }
        return try await session.broadcastTransaction(BroadcastTransactionParams(psbt: psbt, memo: transaction?.memo, simulateOnly: false))
    }

    func signPsbt() async throws {
        guard let session = session else {
            throw TransactionError.invalid(localizedDescription: "Invalid session")
        }
        guard let psbt = unsignedPsbt else {
            throw TransactionError.invalid(localizedDescription: "Invalid psbt")
        }
        let utxos = try await session.getUtxos(GetUnspentOutputsParams(subaccount: subaccount?.pointer ?? 0, numConfs: 0))
        let res = try await session.signPsbt(params: SignPsbtParams(psbt: psbt, utxos: utxos.unspentOutputs))
        self.signedPsbt = res.psbt
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
            } else if unsignedPsbt != nil {
                try await signPsbt()
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
                nodeId: nil
            )
            self.error = error
            throw error
        }
    }

    func sendHWConfirmViewModel() -> SendHWConfirmViewModel {
        SendHWConfirmViewModel(
            isLedger: wm?.isLedger ?? false,
            tx: transaction!,
            denomination: denominationType,
            subaccount: self.subaccount,
            isMultiAddressees: self.multiAddressees)
    }

    func tempSendHWConfirmViewModel() -> SendHWConfirmViewModel {
        SendHWConfirmViewModel(
            isLedger: wm?.isLedger ?? false,
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

    func validateHW(_ address: gdk.Address) async throws -> Bool {
        guard let subaccount = subaccount else {
            throw GaError.GenericError("id_invalid_subaccount".localized)
        }
        return try await BleHwManager.shared.validateAddress(account: subaccount, address: address)
    }

    func sendVerifyOnDeviceViewModel(_ address: gdk.Address) -> HWDialogVerifyOnDeviceViewModel? {
        guard let address = address.address else { return nil }
        let account = AccountsRepository.shared.current
        return HWDialogVerifyOnDeviceViewModel(isLedger: account?.isLedger ?? false,
                                       address: address,
                                       isRedeposit: true,
                                       isDismissible: false)
    }

    func showSignTransactionViaQR() -> Bool {
        if mainAccount?.isHW ?? false && mainAccount?.boardType == .v2c {
            return false
        }
        return wm?.isWatchonly ?? false && [.bitcoinSS, .testnetSS].contains(session?.networkType) && txType != .sweep && !importSignedPsbt
    }

    func showSignTransaction() -> Bool {
        txType == .sweep || !(wm?.isWatchonly ?? false) || (mainAccount?.isHW ?? false) || importSignedPsbt
    }
}
