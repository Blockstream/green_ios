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

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        logger.info("Notification received: \(self.bestAttemptContent?.userInfo.description ?? "", privacy: .public)")
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        let userInfo = bestAttemptContent?.userInfo
        guard let notification = LightningNotification.from(userInfo ?? [:]) as? LightningNotification else {
            logger.error("Invalid notification")
            if let content = bestAttemptContent {
                contentHandler(content)
            }
            return
        }

        if let currentTask = self.getTaskFromNotification(notification: notification) {
            self.currentTask = currentTask
            Task.detached(priority: .high) { @MainActor [weak self] in
                do {
                    guard let xpub = notification.appData else {
                        logger.error("Invalid xpub: \(self?.bestAttemptContent?.userInfo.description ?? "", privacy: .public)")
                        throw NotificationError.InvalidNotification
                    }
                    logger.info("xpub: \(xpub, privacy: .public)")
                    guard let lightningAccount = self?.getLightningAccount(xpub: xpub) else {
                        guard let account = self?.getAccount(xpub: xpub) else {
                            logger.error("Wallet not found")
                            throw NotificationError.WalletNotFound
                        }
                        logger.info("Using account \(account.name, privacy: .public)")
                        currentTask.onShutdown()
                        return
                    }
                    logger.info("Using lightning account \(lightningAccount.name, privacy: .public)")
                    let credentials = try AuthenticationTypeHandler.getAuthKeyLightning(forNetwork: lightningAccount.keychain)
                    logger.info("Breez SDK is not connected, connecting....")
                    if let breezSdk = try await self?.breezSDKConnector.register(credentials: credentials, listener: currentTask) {
                        logger.info("Breez SDK connected successfully")
                        try currentTask.start(breezSDK: breezSdk)
                    }
                } catch {
                    logger.error("Breez SDK connection failed \(error.description() ?? "", privacy: .public)")
                    self?.shutdown()
                    self?.currentTask?.onShutdown()
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
            logger.info("creating task for tx received")
            return RedeemSwapTask(payload: notification.notificationPayload ?? "", logger: logger, contentHandler: contentHandler, bestAttemptContent: bestAttemptContent, dismiss: self.shutdown )
        case .paymentReceived:
            logger.info("creating task for payment received")
            return PaymentReceiverTask(payload: notification.notificationPayload ?? "", logger: logger, contentHandler: contentHandler, bestAttemptContent: bestAttemptContent, dismiss: self.shutdown )
        default:
            return nil
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        logger.error("serviceExtensionTimeWillExpire()")
        
        // iOS calls this function just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content,
        // otherwise the original push payload will be used.
        self.shutdown()
        self.currentTask?.onShutdown()
    }

    private func shutdown() -> Void {
        Task.detached(priority: .high) { @MainActor [weak self] in
            logger.info("shutting down...")
            await self?.breezSDKConnector.unregister()
            logger.info("task unregistered")
        }
    }
}
