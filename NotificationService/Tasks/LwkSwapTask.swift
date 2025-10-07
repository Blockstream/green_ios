import Foundation
import UserNotifications
import os.log
import core
import LiquidWalletKit
import gdk

// MARK: - LWK Event
public struct LwkEvent: Codable {
    enum CodingKeys: String, CodingKey {
        case type
        case event
        case walletHashedId = "wallet_hashed_id"
        case data
    }
    let type: String
    let event: String
    let walletHashedId: String
    let data: String
}

public struct LwkEventData: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case status
    }
    let id: String
    let status: String
}

// MARK: - Lwk swap Task
public class LwkSwapTask {
    public let SWAP_NOTIFICATION_SUCCESS_TITLE = "Swap success"
    public let SWAP_NOTIFICATION_FAILURE_TITLE = "Swap fails"
    public var contentHandler: ((UNNotificationContent) -> Void)?
    public var bestAttemptContent: UNMutableNotificationContent?
    public var dismiss: (() -> Void)?
    public let logger: Logger
    private let event: LwkEvent
    private let account: Account

    public init(account: Account, event: LwkEvent, logger: Logger, contentHandler: ((UNNotificationContent) -> Void)?, bestAttemptContent: UNMutableNotificationContent?, dismiss: @escaping () -> Void) {
        self.account = account
        self.event = event
        self.logger = logger
        self.contentHandler = contentHandler
        self.bestAttemptContent = bestAttemptContent
        self.dismiss = dismiss
    }

    public func start(network: Network, secret: String) async throws {
        logger.info("LwkSwapTask: Starting Lwk swap task")
        let eventData = event.data.replacingOccurrences(of: "'", with: "\"")
        guard let eventData = LwkEventData.from(string: eventData) as? LwkEventData else {
            throw NotificationError.InvalidNotification
        }
        guard let persistentId = try await BoltzController.shared.fetchID(byId: eventData.id) else {
            logger.error("LwkSwapTask: Swap \(eventData.id, privacy: .public) not present")
            throw NotificationError.InvalidSwap
        }
        let swap = try await BoltzController.shared.get(with: persistentId)
        guard let swap = swap, let swapData = swap.data else {
            logger.error("LwkSwapTask: Swap \(eventData.id, privacy: .public) not present")
            throw NotificationError.InvalidSwap
        }
        logger.info("LwkSwapTask: Swap \(eventData.id)")
        if swap.isPending {
            logger.info("LwkSwapTask: Swap not pending")
        }
        GdkInit.defaults().run()
        let lwk = LwkSessionManager()
        try await lwk.connect()
        _ = try await lwk.loginUser(Credentials(mnemonic: secret))
        let data = swapData.data(using: .utf8, allowLossyConversion: false)
        let dict = try? JSONSerialization.jsonObject(with: data ?? Data(), options: []) as? [String: Any]
        let dictSwapType = dict?["swap_type"] as? String
        let swapType = BoltzSwapTypes(rawValue: dictSwapType ?? "")
        switch swapType {
        case .Submarine:
            if let pay = try? await lwk.restorePreparePay(data: swapData) {
                _ = try? await lwk.handlePay(pay: pay)
            }
        case .ReverseSubmarine:
            if let invoice = try? await lwk.restoreInvoice(data: swapData) {
                _ = try? await lwk.handleInvoice(invoice: invoice)
            }
        case nil:
            throw NotificationError.InvalidNotification
        }
        switch eventData.status {
        case "invoice.settled":
            if let bestAttemptContent = bestAttemptContent {
                bestAttemptContent.title = account.name
                bestAttemptContent.body = "Payment received"
                contentHandler?(bestAttemptContent)
            }
        case "invoice.paid":
            if let bestAttemptContent = bestAttemptContent {
                bestAttemptContent.title = account.name
                bestAttemptContent.body = "Payment sent"
                contentHandler?(bestAttemptContent)
            }
        default:
            let silentContent = UNMutableNotificationContent()
            contentHandler?(silentContent)
        }
        dismiss?()
    }

    public func onShutdown() {
        logger.info("LwkSwapTask: Lwk swap task shutting down")
    }
}
