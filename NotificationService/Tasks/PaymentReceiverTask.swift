import UserNotifications
import os.log
import Foundation
import BreezSDK
import core

struct ReceivePaymentNotificationRequest: Codable {
    let payment_hash: String
}

class PaymentReceiverTask: TaskProtocol {
    var TAG: String { return String(describing: self) }
    let PAYMENT_RECEIVED_NOTIFICATION_TITLE = "id_payment_received"
    let PAYMENT_RECEIVED_NOTIFICATION_FAILURE_TITLE = "id_open_wallet_to_receive_a_payment"

    internal var payload: String
    internal var contentHandler: ((UNNotificationContent) -> Void)?
    internal var bestAttemptContent: UNMutableNotificationContent?
    internal var dismiss: (() -> Void)?
    private var logger: Logger
    private var receivedPayment: Payment?

    init(payload: String, logger: Logger, contentHandler: ((UNNotificationContent) -> Void)? = nil, bestAttemptContent: UNMutableNotificationContent? = nil, dismiss: (() -> Void)? = nil) {
        self.payload = payload
        self.contentHandler = contentHandler
        self.bestAttemptContent = bestAttemptContent
        self.logger = logger
        self.dismiss = dismiss
    }

    func start(breezSDK: BlockingBreezServices) async throws {
        do {
            let request = try JSONDecoder().decode(ReceivePaymentNotificationRequest.self, from: self.payload.data(using: .utf8)!)
            let existingPayment = try breezSDK.paymentByHash(hash: request.payment_hash)
            if existingPayment != nil {
                self.receivedPayment = existingPayment
                logger.info("\(self.TAG, privacy: .public): Found payment for hash \(request.payment_hash, privacy: .public)")
                self.onShutdown()
                self.dismiss?()
            }
        } catch let e {
            logger.error("\(self.TAG, privacy: .public): Failed to call start of receive payment notification: \(e, privacy: .public)")
            throw NotificationError.Failed
        }
    }

    func onShutdown() {
        let title = receivedPayment != nil ? PAYMENT_RECEIVED_NOTIFICATION_TITLE : PAYMENT_RECEIVED_NOTIFICATION_FAILURE_TITLE
        displayPushNotification(title: title, threadIdentifier: TAG)
    }

    func onEvent(e: BreezEvent) {
        switch e {
        case .invoicePaid(details: let details):
            self.logger.info("\(self.TAG, privacy: .public): Received payment. Bolt11: \(details.bolt11, privacy: .public)\nPayment Hash:\(details.paymentHash, privacy: .public)")
            receivedPayment = details.payment
        case .synced:
            logger.info("\(self.TAG, privacy: .public): Received synced event")
            if self.receivedPayment != nil {
                logger.info("\(self.TAG, privacy: .public): Received synced event and receivedPayment != nil")
                self.onShutdown()
                self.dismiss?()
            }
        default:
            break
        }
    }
}
