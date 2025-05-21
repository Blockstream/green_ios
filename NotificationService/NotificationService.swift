import Foundation
import UserNotifications
import BreezSDK
import core

struct LnurlInfoMessage: Codable {
    let callback_url: String
    let reply_url: String
}

struct LnurlInvoiceMessage: Codable {
    let reply_url: String
    let amount: UInt64
}

public enum LightningNotificationType: String, Codable {
    case addressTxsConfirmed = "address_txs_confirmed"
    case paymentReceived = "payment_received"
    case swapUpdated = "swap_updated"
}

public struct LightningNotification: Codable {
    enum CodingKeys: String, CodingKey {
        case appData = "app_data"
        case notificationType = "notification_type"
        case notificationPayload = "notification_payload"
    }
    let appData: String?
    let notificationType: LightningNotificationType?
    let notificationPayload: String?
}

public enum NotificationError: Error {
    case InvalidNotification
    case WalletNotFound
    case Failed
    case EventNotFound
}

class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?
    private var currentTask: TaskProtocol?
    private var breezSDKConnector = BreezSDKConnector()
    private var TAG: String { return String(describing: self) }

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void)
    {
        logger.info("\(self.TAG, privacy: .public): Notification received: \(self.bestAttemptContent?.userInfo.description ?? "", privacy: .public)")
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        let userInfo = bestAttemptContent?.userInfo
        if let lightningNotification = LightningNotification.from(userInfo ?? [:]) as? LightningNotification {
            Task.detached(priority: .high) { @MainActor [weak self] in
                await self?.didReceiveLightning(lightningNotification)
            }
        } else if let meldNotification = MeldEvent.from(userInfo ?? [:]) as? MeldEvent {
            Task.detached(priority: .high) { @MainActor [weak self] in
                await self?.didReceiveMeld(meldNotification)
            }
        } else {
            logger.info("\(self.TAG, privacy: .public): Invalid notification")
            if let content = bestAttemptContent {
                contentHandler(content)
            }
            return
        }
    }

    func didReceiveMeld(_ notification: MeldEvent) async {
        let currentTask = MeldTransactionTask(
            event: notification,
            logger: logger,
            contentHandler: contentHandler,
            bestAttemptContent: bestAttemptContent,
            dismiss: shutdown
        )
        guard let externalCustomerId = notification.payload.externalCustomerId else {
            logger.error("\(self.TAG, privacy: .public): Missing externalCustomerId in Meld transaction payload")
            currentTask.onShutdown()
            shutdown()
            return
        }
        guard let _ = getAccount(xpub: externalCustomerId) else {
            logger.error("\(self.TAG, privacy: .public): Wallet not found")
            currentTask.onShutdown()
            shutdown()
            return
        }
        let task = Task { try await currentTask.start() }
        switch await task.result {
        case .success:
            logger.info("\(self.TAG, privacy: .public): MeldTransactionTask starts successfully")
        case .failure(let err):
            logger.error("\(self.TAG, privacy: .public): MeldTransactionTask fails with \(err.description(), privacy: .public)")
            currentTask.onShutdown()
            shutdown()
        }
    }

    func didReceiveLightning(_ notification: LightningNotification) async {
        let currentTask = self.getTaskFromNotification(notification: notification)
        guard let currentTask = currentTask else { return }
        self.currentTask = currentTask
        guard let xpub = notification.appData else {
            logger.error("\(self.TAG, privacy: .public): Invalid xpub: \(self.bestAttemptContent?.userInfo.description ?? "", privacy: .public)")
            currentTask.onShutdown()
            shutdown()
            return
        }
        logger.info("\(self.TAG, privacy: .public): xpub: \(xpub, privacy: .public)")
        guard let account = getAccount(xpub: xpub) else {
            logger.error("\(self.TAG, privacy: .public): Wallet not lightning found")
            currentTask.onShutdown()
            shutdown()
            return
        }
        logger.info("\(self.TAG, privacy: .public): Using lightning wallet \(account.name, privacy: .public)")
        let task = Task { [weak self] in
            logger.info("\(self?.TAG ?? "", privacy: .public): Breez SDK is not connected, connecting....")
            let credentials = try AuthenticationTypeHandler.getCredentials(method: .AuthKeyLightning, for: account.keychainLightning)
            let breezSdk = try await self?.breezSDKConnector.register(credentials: credentials, listener: currentTask)
            logger.info("\(self?.TAG ?? "", privacy: .public): Breez SDK connected successfully")
            if let breezSdk = breezSdk {
                try await currentTask.start(breezSDK: breezSdk)
            }
        }
        switch await task.result {
        case .success:
            logger.info("\(self.TAG, privacy: .public): MeldTransactionTask starts successfully")
        case .failure(let err):
            logger.error("\(self.TAG, privacy: .public): Breez SDK connection failed \(err.description(), privacy: .public)")
            currentTask.onShutdown()
            shutdown()
        }
    }

    func getAccount(xpub: String) -> Account? {
        let accounts = AccountsRepository.shared.accounts
        return accounts
            .filter { $0.xpubHashId == xpub }
            .first
    }

    func getTaskFromNotification(notification: LightningNotification) -> TaskProtocol? {
        switch notification.notificationType {
        case .addressTxsConfirmed:
            logger.info("\(self.TAG, privacy: .public): creating task for tx received")
            return ConfirmTransactionTask(payload: notification.notificationPayload ?? "", logger: logger, contentHandler: contentHandler, bestAttemptContent: bestAttemptContent, dismiss: self.shutdown )
        case .paymentReceived:
            logger.info("\(self.TAG, privacy: .public): creating task for payment received")
            return PaymentReceiverTask(payload: notification.notificationPayload ?? "", logger: logger, contentHandler: contentHandler, bestAttemptContent: bestAttemptContent, dismiss: self.shutdown )
        case .swapUpdated:
            logger.info("\(self.TAG, privacy: .public): creating task for swap update")
            return SwapUpdateTask(payload: notification.notificationPayload ?? "", logger: logger, contentHandler: contentHandler, bestAttemptContent: bestAttemptContent, dismiss: self.shutdown )
        default:
            return nil
        }
    }

    override func serviceExtensionTimeWillExpire() {
        logger.info("\(self.TAG, privacy: .public): serviceExtensionTimeWillExpire()")

        // iOS calls this function just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content,
        // otherwise the original push payload will be used.
        self.currentTask?.onShutdown()
        self.shutdown()
    }

    private func shutdown() -> Void {
        Task.detached(priority: .high) { @MainActor [weak self] in
            logger.info("\(self?.TAG ?? "", privacy: .public): shutting down...")
            await self?.breezSDKConnector.unregister()
            logger.info("\(self?.TAG ?? "", privacy: .public): task unregistered")
        }
    }
}
