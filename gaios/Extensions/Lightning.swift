import Foundation
import BreezSDK
import lightning
import gdk

extension SendTransactionSuccess {
    static func create(from payment: Payment) -> SendTransactionSuccess {
        SendTransactionSuccess(paymentId: payment.id)
    }
    
    static func create(from successData: LnUrlPaySuccessData) -> SendTransactionSuccess {
        var message: String?
        var url: String? 
        switch successData.successAction {
        case .aes(let result):
            switch result {
            case .decrypted(let data):
                message = "\(data.description)\n\(data.plaintext)"
            default:
                break
            }
        case .message(let data):
            message = data.message
        case .url(let data):
            message = data.description
            url = data.url
        default:
            break
        }
        return SendTransactionSuccess(
            message: message,
            url: url
        )
    }
}
