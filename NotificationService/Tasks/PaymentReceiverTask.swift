import UserNotifications
import os.log
import Foundation
import BreezSDK
import core

struct ReceivePaymentNotificationRequest: Codable {
    let payment_hash: String
}

class PaymentReceiverTask: TaskProtocol {
    static let NOTIFICATION_THREAD_PAYMENT_RECEIVED = "PAYMENT_RECEIVED"

    internal var payload: String
    internal var contentHandler: ((UNNotificationContent) -> Void)?
    internal var bestAttemptContent: UNMutableNotificationContent?
    internal var dismiss: (() -> Void)?
    private var logger: Logger
    private var receivedPayment: Payment? = nil

    init(payload: String, logger: Logger, contentHandler: ((UNNotificationContent) -> Void)? = nil, bestAttemptContent: UNMutableNotificationContent? = nil, dismiss: (() -> Void)? = nil) {
        self.payload = payload
        self.contentHandler = contentHandler
        self.bestAttemptContent = bestAttemptContent
        self.logger = logger
        self.dismiss = dismiss
    }

    func start(breezSDK: BlockingBreezServices) throws {
        do {
            let request = try JSONDecoder().decode(ReceivePaymentNotificationRequest.self, from: self.payload.data(using: .utf8)!)
            let existingPayment = try breezSDK.paymentByHash(hash: request.payment_hash)
            if existingPayment != nil {
                self.receivedPayment = existingPayment
                logger.info("Found payment for hash \(request.payment_hash, privacy: .public)")
                self.onShutdown()
                self.dismiss?()
            }
        } catch let e {
            logger.error("Failed to call start of receive payment notification: \(e, privacy: .public)")
            throw NotificationError.Failed
        }
    }

    func onShutdown() {
        if receivedPayment != nil {
            self.displayPushNotification(title: "Payment received", threadIdentifier: PaymentReceiverTask.NOTIFICATION_THREAD_PAYMENT_RECEIVED)
        } else {
            self.displayPushNotification(title: "Open wallet to receive a payment", threadIdentifier: PaymentReceiverTask.NOTIFICATION_THREAD_PAYMENT_RECEIVED)
        }
    }

    func onEvent(e: BreezEvent) {
        switch e {
        case .invoicePaid(details: let details):
            self.logger.info("Received payment. Bolt11: \(details.bolt11, privacy: .public)\nPayment Hash:\(details.paymentHash, privacy: .public)")
            receivedPayment = details.payment
        case .synced:
            logger.error("Received synced event")
            if self.receivedPayment != nil {
                logger.info("Received synced event and receivedPayment != nil")
                self.onShutdown()
                self.dismiss?()
            }
        default:
            break
        }
    }
}
