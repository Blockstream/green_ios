import UserNotifications
import os.log
import Foundation
import BreezSDK
import core

struct SwapUpdateTaskNotificationRequest: Codable {
    let id: String
    let status: String
}

class SwapUpdateTask: TaskProtocol {
    var TAG: String { return String(describing: self) }
    let SWAP_UPDATE_CONFIRMED_NOTIFICATION_FAILURE_TITLE = "Open the app to complete swap"
    let SWAP_UPDATE_CONFIRMED_NOTIFICATION_TITLE = "Swap Update confirmed"

    internal var payload: String
    internal var contentHandler: ((UNNotificationContent) -> Void)?
    internal var bestAttemptContent: UNMutableNotificationContent?
    internal var dismiss: (() -> Void)?
    private var logger: Logger

    init(payload: String, logger: Logger, contentHandler: ((UNNotificationContent) -> Void)? = nil, bestAttemptContent: UNMutableNotificationContent? = nil, dismiss: (() -> Void)? = nil) {
        self.payload = payload
        self.contentHandler = contentHandler
        self.bestAttemptContent = bestAttemptContent
        self.logger = logger
        self.dismiss = dismiss
    }

    func start(breezSDK: BlockingBreezServices) throws {
        do {
            let request = try JSONDecoder().decode(SwapUpdateTaskNotificationRequest.self, from: self.payload.data(using: .utf8)!)
            logger.info("\(self.TAG, privacy: .public): id \(request.id, privacy: .public), status: \(request.status, privacy: .public)")
        } catch let e {
            logger.error("\(self.TAG, privacy: .public): Failed to call start of swap update notification: \(e, privacy: .public)")
            throw NotificationError.Failed
        }
    }

    func onShutdown() { // silent notification
    }

    func onEvent(e: BreezEvent) {
        switch e {
        case .invoicePaid(details: let details):
            self.logger.info("\(self.TAG, privacy: .public): Received payment. Bolt11: \(details.bolt11, privacy: .public)\nPayment Hash:\(details.paymentHash, privacy: .public)")
        case .synced:
            logger.info("\(self.TAG, privacy: .public): Received synced event")
        case .reverseSwapUpdated(details: let revSwapInfo):
            logger.info("\(self.TAG, privacy: .public): Received reverse swap updated event: \(revSwapInfo.id, privacy: .public), current status: \(revSwapInfo.status.description(), privacy: .public)")
        case .swapUpdated(details: let swapInfo):
            logger.info("\(self.TAG, privacy: .public): Received swap updated event: \(swapInfo.bitcoinAddress, privacy: .public), current status: \(swapInfo.status.description(), privacy: .public)")
        default:
            break
        }
    }
}
