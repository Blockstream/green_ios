import Foundation
import core
import gdk
import LiquidWalletKit
import greenaddress

@MainActor
final class SendSuccessViewModel: Sendable {
    let sendTransactionSuccess: SendTransactionSuccess
    let tx: gdk.Transaction
    let total: String?
    let delegate: SendSuccessViewModelDelegate?

    internal init(sendTransactionSuccess: SendTransactionSuccess, tx: gdk.Transaction, total: String?, delegate: SendSuccessViewModelDelegate?) {
        self.sendTransactionSuccess = sendTransactionSuccess
        self.tx = tx
        self.total = total
        self.delegate = delegate
    }
    
    func urlForTx() -> URL? {
        guard let txExplorerUrl = tx.subaccount?.gdkNetwork.txExplorerUrl, let
                txHash = sendTransactionSuccess.txHash else {
            return nil
        }
        return URL(string: "\(txExplorerUrl)\(txHash)")
    }

    func urlForTxUnblinded() -> URL? {
        guard let txExplorerUrl = tx.subaccount?.gdkNetwork.txExplorerUrl,
                let txHash = sendTransactionSuccess.txHash else {
            return nil
        }
        let blindingUrl = tx.blindingUrlString(address: txHash)
        return URL(string: "\(txExplorerUrl)\(txHash)\(blindingUrl)")
    }
    
    func url() -> URL? {
        if tx.isLightning {
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
