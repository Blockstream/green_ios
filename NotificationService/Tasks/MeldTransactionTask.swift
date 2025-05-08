import Foundation
import UserNotifications
import os.log

// MARK: - Meld Transaction Status
public enum MeldTransactionStatus: String {
    case pending = "PENDING"
    case processing = "PROCESSING"
    case settling = "SETTLING"
    case completed = "COMPLETED"
    case failed = "FAILED"
    case cancelled = "CANCELLED"

    var notificationTitle: String {
        switch self {
        case .pending: return "Transaction Pending"
        case .processing: return "Transaction Processing"
        case .settling: return "Transaction Settling"
        case .completed: return "Transaction Completed"
        case .failed: return "Transaction Failed"
        case .cancelled: return "Transaction Cancelled"
        }
    }

    var notificationBody: String {
        switch self {
        case .pending: return "Your transaction is pending confirmation"
        case .processing: return "Your transaction is being processed"
        case .settling: return "Your transaction is being settled"
        case .completed: return "Your transaction has been completed successfully"
        case .failed: return "Your transaction could not be completed"
        case .cancelled: return "Your transaction was cancelled"
        }
    }
}

// MARK: - Meld Transaction Task
public class MeldTransactionTask {
    public var contentHandler: ((UNNotificationContent) -> Void)?
    public var bestAttemptContent: UNMutableNotificationContent?
    public var dismiss: (() -> Void)?
    public let logger: Logger
    private let TAG: String = "MeldTransactionTask"
    private static let MELD_PREFIX_LABEL = "MELD_FETCH_REQUEST_TRANSACTIONS_FOR_"
    private let event: MeldEvent

    public init(event: MeldEvent, logger: Logger, contentHandler: ((UNNotificationContent) -> Void)?, bestAttemptContent: UNMutableNotificationContent?, dismiss: @escaping () -> Void) {
        self.event = event
        self.logger = logger
        self.contentHandler = contentHandler
        self.bestAttemptContent = bestAttemptContent
        self.dismiss = dismiss
    }

    public func start() async throws {
        logger.info("\(self.TAG, privacy: .public): Starting Meld transaction task")
        // Verify we have the externalCustomerId
        guard let externalCustomerId = event.payload.externalCustomerId else {
            logger.error("\(self.TAG, privacy: .public): Missing externalCustomerId in Meld transaction payload")
            throw NotificationError.InvalidNotification
        }
        if let content = bestAttemptContent {
            // Parse the transaction status
            let status = MeldTransactionStatus(rawValue: event.payload.paymentTransactionStatus.uppercased()) ?? .processing
            // Set notification title and body based on status
            content.title = status.notificationTitle
            content.body = status.notificationBody
            // Add transaction data to userInfo
            content.userInfo["eventId"] = event.eventId
            content.userInfo["eventType"] = event.eventType
            content.userInfo["timestamp"] = event.timestamp
            content.userInfo["transactionId"] = event.payload.paymentTransactionId
            content.userInfo["customerId"] = event.payload.customerId
            content.userInfo["externalCustomerId"] = externalCustomerId
            content.userInfo["status"] = event.payload.paymentTransactionStatus
            content.userInfo["accountId"] = event.payload.accountId
            content.userInfo["externalSessionId"] = event.payload.externalSessionId
            // Add a thread identifier based on the externalCustomerId
            content.threadIdentifier = externalCustomerId
            logger.info("\(self.TAG, privacy: .public): Notification content updated with transaction data for user \(externalCustomerId, privacy: .public)")

            // setup refresh flag
            let defaults = UserDefaults(suiteName: Bundle.main.appGroup)
            defaults?.setValue(true, forKey: "\(MeldTransactionTask.MELD_PREFIX_LABEL)_\(externalCustomerId)")
            contentHandler?(content)
        }
        dismiss?()
    }

    public func onShutdown() {
        logger.info("\(self.TAG, privacy: .public): Meld transaction task shutting down")
    }
} 
