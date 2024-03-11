import UserNotifications
import Combine
import os.log
import notify
import BreezSDK
import core
import gdk

struct LnurlInfoMessage: Codable {
    let callback_url: String
    let reply_url: String
}

struct LnurlInvoiceMessage: Codable {
    let reply_url: String
    let amount: UInt64
}

protocol SDKBackgroundTask: EventListener {
    func start(breezSDK: BlockingBreezServices)
    func onShutdown()
    func displayPushNotification(text: String)
    func displayFailedPushNotification()
}

class NotificationService: UNNotificationServiceExtension {
    
    
    private var lightningSession: LightningSessionManager? = nil
    
    private var contentHandler: ((UNNotificationContent) -> Void)? = nil
    private var bestAttemptContent: UNMutableNotificationContent? = nil
    private var currentTask: SDKBackgroundTask? = nil
    
    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        logger.info("Notification received")
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        if let currentTask = self.getTaskFromNotification() {
            self.currentTask = currentTask
            Task() {
                do {
                    guard let xpub = bestAttemptContent?.userInfo["app_data"] as? String else {
                        throw SdkError.Generic(message: "No xpub found")
                    }
                    logger.info("Get lightning account mnemonic")
                    let credentials = try self.getCredentials(xpub: xpub)
                    logger.info("Breez SDK is not connected, connecting....")
                    try await breezConnect(credentials: credentials, listener: currentTask)
                    logger.info("Breez SDK connected successfully")
                    if let breezSdk = self.lightningSession?.lightBridge?.breezSdk {
                        currentTask.start(breezSDK: breezSdk)
                    }
                } catch {
                    logger.error("Breez SDK connection failed \(error.description() ?? "")")
                    currentTask.displayFailedPushNotification()
                    Task { await self.shutdown() }
                }
            }
        }
    }

    func getCredentials(xpub: String) throws -> Credentials {
        let accounts = AccountsRepository.shared.accounts
        let lightningShortcutsAccount = accounts
            .compactMap { $0.getDerivedLightningAccount() }
            .filter { $0.xpubHashId == xpub }
            .first
        guard let account = lightningShortcutsAccount else {
            throw SdkError.Generic(message: "Wallet not found")
        }
        logger.info("\(account.name) lightning account")
        return try AuthenticationTypeHandler.getAuthKeyLightning(forNetwork: account.keychain)
    }

    func breezConnect(credentials: Credentials, listener: EventListener) async throws {
        GdkInit.defaults().run()
        self.lightningSession = LightningSessionManager(NetworkSecurityCase.bitcoinSS.gdkNetwork)
        self.lightningSession?.listener = listener
        let walletIdentifier =  try self.lightningSession?.walletIdentifier(credentials: credentials)
        _ = try await self.lightningSession?.loginUser(credentials: credentials, restore: false)
    }

    func breezDisconnect() async throws {
        try await self.lightningSession?.disconnect()
    }
    
    func getTaskFromNotification() -> SDKBackgroundTask? {
        guard let content = bestAttemptContent else {
            return nil
        }
        guard let notificationType = content.userInfo["notification_type"] as? String else {
            return nil
        }
        guard let notificationXpub = content.userInfo["app_data"] as? String else {
            return nil
        }
        logger.info("Notification payload: \(content.userInfo)")
        logger.info("Notification type: \(notificationType)")
        
        switch(notificationType) {
        case "tx_received":
            logger.info("creating task for tx received")
            return TxReceiverTask(logger: logger, contentHandler: contentHandler, bestAttemptContent: bestAttemptContent)
        case "payment_received":
            logger.info("creating task for payment received")
            return PaymentReceiverTask(logger: logger, contentHandler: contentHandler, bestAttemptContent: bestAttemptContent)
        default:
            return nil
        // TODO other cases
        /*case "lnurlpay_info":
            guard let messageData = content.userInfo["notification_payload"] as? String else {
                contentHandler!(content)
                return nil
            }
            logger.info("lnurlpay_info data string: \(messageData)")
            let jsonData = messageData.data(using: .utf8)!
            do {
                let lnurlInfoMessage: LnurlInfoMessage = try JSONDecoder().decode(LnurlInfoMessage.self, from: jsonData)
                
                logger.info("creting lnurl pay task, payload: \(lnurlInfoMessage.stringify() ?? "")")
                return LnurlPayInfo(message: lnurlInfoMessage, logger: logger, contentHandler: contentHandler, bestAttemptContent: bestAttemptContent)
            } catch let e {
                logger.info("Error in parsing request: \(e)")
                return nil
            }
        case "lnurlpay_invoice":
            guard let messageData = content.userInfo["notification_payload"] as? String else {
                contentHandler!(content)
                return nil
            }
            logger.info("lnurlpay_invoice data string: \(messageData)")
            let jsonData = messageData.data(using: .utf8)!
            do {
                let lnurlInvoiceMessage: LnurlInvoiceMessage = try JSONDecoder().decode(LnurlInvoiceMessage.self, from: jsonData)

                logger.info("creting lnurl pay task, payload: \(lnurlInvoiceMessage.stringify() ?? "")")
                return LnurlPayInvoice(message: lnurlInvoiceMessage, logger: logger, contentHandler: contentHandler, bestAttemptContent: bestAttemptContent)
            } catch let e {
                logger.info("Error in parsing request: \(e)")
                return nil
            }
        default:
            return nil*/
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        logger.error("serviceExtensionTimeWillExpire()")
        
        // iOS calls this function just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content,
        // otherwise the original push payload will be used.
        Task { await self.shutdown() }
    }

    private func shutdown() async -> Void {
        logger.info("shutting down...")
        try? await breezDisconnect()
        logger.info("task unregistered")
        self.currentTask?.onShutdown()
    }
}


class SDKLogListener : LogStream {
    private var logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func log(l: LogEntry) {
        if l.level != "TRACE" {
            logger.info("greenlight: [\(l.level)] \(l.line)")
        }
    }
}

