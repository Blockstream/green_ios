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
        logger.info("LwkSwapTask: eventData \(eventData.toDict()?.stringify() ?? "", privacy: .public)")
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
        let lwkSession = LwkSessionManager(newNotificationDelegate: nil)
        try await lwkSession.connect()
        _ = try await lwkSession.loginUser(Credentials(mnemonic: secret))
        let monitor = SwapMonitor(mainAccount: account, lwkSession: lwkSession)
        switch swap.type {
        case .Submarine:
            if let pay = try? await lwkSession.restorePreparePay(data: swapData) {
                _ = try? await monitor.loopSwap(swap: SwapResponse.submarine(pay))
            }
        case .ReverseSubmarine:
            if let invoice = try? await lwkSession.restoreInvoice(data: swapData) {
                _ = try? await monitor.loopSwap(swap: SwapResponse.reverseSubmarine(invoice))
            }
        case .Chain:
            if let lockup = try? await lwkSession.restoreLockup(data: swapData) {
                _ = try? await monitor.loopSwap(swap: SwapResponse.chain(lockup))
            }
        case nil:
            throw NotificationError.InvalidNotification
        }
        // Setup notification content
        bestAttemptContent?.title = account.name
        switch eventData.status {
        case "transaction.mempool":
            switch swap.type {
            case .Submarine, .ReverseSubmarine:
                bestAttemptContent?.body = "Processing Lightning payment.."
            case .Chain:
                bestAttemptContent?.body = "Processing chain swap.."
            case .none:
                break
            }
        default:
            // Eventually don't show any message
            //let silentContent = UNMutableNotificationContent()
            //contentHandler?(silentContent)
            break
        }
        if let bestAttemptContent {
            contentHandler?(bestAttemptContent)
        }
        dismiss?()
    }

    public func onShutdown() {
        logger.info("LwkSwapTask: Lwk swap task shutting down")
    }
}
