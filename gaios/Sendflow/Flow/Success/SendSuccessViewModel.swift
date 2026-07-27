import Foundation
import core
import LiquidWalletKit
import greenaddress

@MainActor
final class SendSuccessViewModel: Sendable {
    let sendTransactionSuccess: SendTransactionSuccess
    let tx: core.Transaction
    let subaccount: Account?
    let total: String?
    let delegate: SendSuccessViewModelDelegate?

    internal init(sendTransactionSuccess: SendTransactionSuccess, tx: core.Transaction, subaccount: Account? = nil, total: String?, delegate: SendSuccessViewModelDelegate?) {
        self.sendTransactionSuccess = sendTransactionSuccess
        self.tx = tx
        self.subaccount = subaccount
        self.total = total
        self.delegate = delegate
    }

    func urlForTx() -> URL? {
        let explorerUrl = subaccount?.gdkNetwork.txExplorerUrl ?? tx.networkIdInjected?.gdkNetwork.txExplorerUrl
        return sendTransactionSuccess.urlForTx(explorerUrl: explorerUrl) ?? tx.urlForTx(explorerUrl: explorerUrl)
    }

    func urlForTxUnblinded() -> URL? {
        let explorerUrl = subaccount?.gdkNetwork.txExplorerUrl ?? tx.networkIdInjected?.gdkNetwork.txExplorerUrl
        return tx.urlForTxUnblinded(explorerUrl: explorerUrl) ?? urlForTx()
    }

    func url() -> URL? {
        let isLightning = subaccount?.isLightning ?? tx.isLightning
        if isLightning {
            if let url = sendTransactionSuccess.url {
                return URL(string: url)
            }
            return nil
        } else if tx.isLiquid {
            return urlForTxUnblinded()
        } else {
            return urlForTx()
        }
    }

    func onShare() {
        if let url = url() {
            delegate?.sendSuccessViewModelDidShare(self, url: url)
        }
    }

    func onClose() {
        delegate?.sendSuccessViewModelDidFinish(self)
    }
}
