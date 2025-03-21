import Foundation
import UserNotifications
import os.log
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

    private var contentHandler: ((UNNotificationContent) -> Void)? = nil
    private var bestAttemptContent: UNMutableNotificationContent? = nil
    private var currentTask: TaskProtocol? = nil
    private var breezSDKConnector = BreezSDKConnector()
    private var TAG: String { return String(describing: self) }

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
            logger.info("\(self.TAG, privacy: .public): Notification received: \(self.bestAttemptContent?.userInfo.description ?? "", privacy: .public)")
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        let userInfo = bestAttemptContent?.userInfo
        guard let notification = LightningNotification.from(userInfo ?? [:]) as? LightningNotification else {
            logger.info("\(self.TAG, privacy: .public): Invalid notification")
            if let content = bestAttemptContent {
                contentHandler(content)
            }
            return
        }
        if let currentTask = self.getTaskFromNotification(notification: notification) {
            self.currentTask = currentTask
            Task.detached(priority: .high) { @MainActor [weak self] in
                let TAG = self?.TAG ?? ""
                do {
                    guard let xpub = notification.appData else {
                        logger.error("\(TAG, privacy: .public): Invalid xpub: \(self?.bestAttemptContent?.userInfo.description ?? "", privacy: .public)")
                        throw NotificationError.InvalidNotification
                    }
                    logger.info("\(TAG, privacy: .public): xpub: \(xpub, privacy: .public)")
                    guard let lightningAccount = self?.getLightningAccount(xpub: xpub) else {
                        guard let account = self?.getAccount(xpub: xpub) else {
                            logger.error("\(TAG, privacy: .public): Wallet not found")
                            return
                        }
                        logger.error("\(TAG, privacy: .public): Wallet not lightning found: \(account.name, privacy: .public)")
                        currentTask.onShutdown()
                        return
                    }
                    logger.info("\(TAG, privacy: .public): Using lightning wallet \(lightningAccount.name, privacy: .public)")
                    logger.info("\(TAG, privacy: .public): Breez SDK is not connected, connecting....")
                    let credentials = try AuthenticationTypeHandler.getCredentials(method: .AuthKeyLightning, for: lightningAccount.keychain)
                    if let breezSdk = try await self?.breezSDKConnector.register(credentials: credentials, listener: currentTask) {
                        logger.info("\(TAG, privacy: .public): Breez SDK connected successfully")
                        try currentTask.start(breezSDK: breezSdk)
                    }
                } catch {
                    logger.error("\(TAG, privacy: .public): Breez SDK connection failed \(error.description() ?? "", privacy: .public)")
                    self?.currentTask?.onShutdown()
                    self?.shutdown()
                }
            }
        }
    }

    func getLightningAccount(xpub: String) -> Account? {
        let accounts = AccountsRepository.shared.accounts
        return accounts
            .compactMap { $0.getDerivedLightningAccount() }
            .filter { $0.xpubHashId == xpub }
            .first
    }

    func getAccount(xpub: String) -> Account? {
        let accounts = AccountsRepository.shared.accounts
        return accounts
            .filter { $0.xpubHashId == xpub }
            .first
    }

    func getTaskFromNotification(notification: LightningNotification) -> TaskProtocol? {
        switch(notification.notificationType) {
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
