import Foundation
import core
import gdk
import greenaddress
import UIKit
import BreezSDK
import LiquidWalletKit

class SendLightningViewModel {
    
    let liquidAccount: WalletItem
    let invoice: Bolt11Invoice
    var tx = gdk.Transaction([:])
    var assetid: String { liquidAccount.networkType.gdkNetwork.getFeeAsset() }
    var asset: AssetInfo? { WalletManager.current?.info(for: assetId) }
    var assetImage: UIImage? { WalletManager.current?.image(for: assetId) }
    var sendTransaction: SendTransactionSuccess?
    var swapPayResponse: PreparePayResponse?
    
    init(liquidAccount: WalletItem, invoice: Bolt11Invoice, denominationType: DenominationType, isFiat: Bool = false) {
        self.liquidAccount = liquidAccount
        self.invoice = invoice
        self.denominationType = denominationType
        self.isFiat = isFiat
    }
    
    var lwk: LwkSessionManager {
        get throws {
            guard let lwk = WalletManager.current?.lwkSession else {
                throw GaError.GenericError("No LWK account")
            }
            return lwk
        }
    }
    
    var liquidSession: SessionManager {
        get throws {
            guard let session = liquidAccount.session else {
                throw GaError.GenericError("Invalid session")
            }
            return session
        }
    }

    func createSwap(invoice: String) async throws -> PreparePayResponse {
        let xpub = AccountsRepository.shared.current?.xpubHashId
        let existingSwapIds = try await BoltzController.shared.fetchIDs(byXpubHashId: xpub, byInvoice: invoice)
        if let swapId = existingSwapIds.first {
            let swap = try await BoltzController.shared.get(with: swapId)
            guard let pay = try await lwk.restorePreparePay(data: swap?.data ?? "") else {
                throw GaError.GenericError("Invalid restored swap")
            }
            return pay
        }
        let address = try await liquidSession.getReceiveAddress(subaccount: liquidAccount.pointer)
        guard let address = address.address else {
            throw GaError.GenericError("Invalid address")
        }
        let refundAddress = try LiquidWalletKit.Address(s: address)
        return try await lwk.preparePay(invoice: invoice, refundAddress: refundAddress)
    }

    func createLiquidTx(uri: String) async throws -> gdk.Transaction {
        var txLiquid = Transaction([:], subaccountId: liquidAccount.id)
        txLiquid.feeRate = try await liquidSession.getFeeEstimates()?.first ?? liquidSession.gdkNetwork.defaultFee
        let unspent = try await liquidSession.getUnspentOutputs(GetUnspentOutputsParams(subaccount: liquidAccount.pointer, numConfs: 0))
        txLiquid.utxos = unspent
        txLiquid.addressees = [Addressee.from(address: uri, satoshi: nil, assetId: assetid)]
        txLiquid = try await liquidSession.createTransaction(tx: txLiquid)
        return txLiquid
    }

    func prepareTx() async throws {
        do {
            let swap = try await createSwap(invoice: invoice.description)
            let uri = try swap.uri()
            self.swapPayResponse = swap
            self.tx = try await createLiquidTx(uri: uri)
        } catch {
            switch error as? LwkError {
            case .MagicRoutingHint(_, _, let uri):
                self.tx = try await createLiquidTx(uri: uri)
            default:
                throw error
            }
        }
    }

    private func sendTx() async throws {
        tx = try await liquidSession.blindTransaction(tx: tx)
        tx = try await liquidSession.signTransaction(tx: tx)
        if let error = tx.error {
            throw TransactionError.invalid(localizedDescription: error)
        }
        sendTransaction = try await liquidSession.sendTransaction(tx: tx)
    }

    func send() async throws {
        AnalyticsManager.shared.startSendTransaction()
        AnalyticsManager.shared.startFailedTransaction()
        let segment = AnalyticsManager.TransactionSegmentation(
            transactionType: .lwkSwap,
            addressInputType: .paste,
            sendAll: false)
        do {
            try await sendTx()
            AnalyticsManager.shared.endSendTransaction(
                account: AccountsRepository.shared.current,
                walletItem: liquidAccount,
                transactionSgmt: segment,
                withMemo: false)
        } catch {
            AnalyticsManager.shared.failedTransaction(
                account: AccountsRepository.shared.current,
                walletItem: liquidAccount,
                transactionSgmt: segment,
                withMemo: false,
                prettyError: error.description().localized,
                nodeId: nil
            )
        }
    }

    var denominationType: DenominationType
    var isFiat = false
    var error: Error?
    var addressee: Addressee? { tx.addressees.first }
    var address: String? { addressee?.address }
    var assetId: String { addressee?.assetId ?? liquidAccount.gdkNetwork.getFeeAsset() }
    var sendAll: Bool { addressee?.isGreedy ?? false}
    var invoiceSatoshi: UInt64? { invoice.amountMilliSatoshis()?.satoshi }
    var swapSatoshi: UInt64? { try? swapPayResponse?.uriAmount().satoshi }

    var recipientAmount: Balance? {
        let amount = swapPayResponse != nil ? invoiceSatoshi : txSatoshi
        return Balance.fromSatoshi(amount ?? 0, assetId: assetId)
    }
    var txFee: Balance? {
        Balance.fromSatoshi(tx.fee ?? 0, assetId: tx.feeAsset)
    }
    var txSatoshi: UInt64? {
        let feeAsset = NetworkSecurityCase.liquidSS.gdkNetwork.getFeeAsset()
        if let amount = tx.amounts[feeAsset] {
            return UInt64(abs(amount))
        }
        return nil
    }
    var swapFee: Balance? {
        Balance.fromSatoshi((try? swapPayResponse?.fee()) ?? 0, assetId: tx.feeAsset)
    }
    var totalFee: Balance? {
        Balance.fromSatoshi((swapFee?.satoshi ?? 0) + (txFee?.satoshi ?? 0), assetId: tx.feeAsset)
    }
    var totalAmount: Balance? {
        let feeAsset = NetworkSecurityCase.liquidSS.gdkNetwork.getFeeAsset()
        var amount = abs(tx.amounts[feeAsset] ?? 0)
        if feeAsset == assetId {
            amount += Int64(tx.fee ?? 0)
        }
        return Balance.fromSatoshi(amount, assetId: assetId)
    }

    var recipientAmountDenomText: String? { recipientAmount?.toText(denominationType) }
    var recipientAmountFiatText: String? { recipientAmount?.toFiatText() }
    var totalFeeDenomText: String? { totalFee?.toText(denominationType) }
    var totalFeeFiatText: String? { totalFee?.toFiatText() }
    var totalDenomText: String? { totalAmount?.toText(denominationType) }
    var totalFiatText: String? { totalAmount?.toFiatText() }

    var recipientAmountText: String? { isFiat ? recipientAmountFiatText : recipientAmountDenomText }
    var recipientSubamountText: String? { isFiat ? recipientAmountDenomText : recipientAmountFiatText}
    var totalFeeText: String? { isFiat ? totalFeeFiatText : totalFeeDenomText }
    var totalText: String? { isFiat ? totalFiatText : totalDenomText }
    var conversionText: String? { isFiat ? totalDenomText : totalFiatText }
    var addressTitle: String { "id_recipient".localized }
    var amountTitle: String { "id_recipient_receives".localized }

    func urlForTx() -> URL? {
        return URL(string: (liquidAccount.gdkNetwork.txExplorerUrl ?? "") + (sendTransaction?.txHash ?? ""))
    }

    func urlForTxUnblinded() -> URL? {
        return URL(string: (liquidAccount.gdkNetwork.txExplorerUrl ?? "") + (sendTransaction?.txHash ?? "") + (tx.blindingUrlString(address: address)))
    }

}
