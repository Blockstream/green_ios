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
}

#if DEBUG && true
fileprivate var log = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "BreezManager"
)
#else
fileprivate var log = Logger(OSLog.disabled)
#endif

class NotificationService: UNNotificationServiceExtension {
    
    
    private var lightningSession: LightningSessionManager? = nil
    
    private var contentHandler: ((UNNotificationContent) -> Void)? = nil
    private var bestAttemptContent: UNMutableNotificationContent? = nil
    private var currentTask: SDKBackgroundTask? = nil
    
    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        log.info("Notification received")
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let currentTask = self.getTaskFromNotification() {
            self.currentTask = currentTask
            
            Task() {
                do {
                    log.info("Get lightning account mnemonic")
                    let credentials = try self.getCredentials()
                    log.info("Breez SDK is not connected, connecting....")
                    try await breezConnect(credentials: credentials, listener: currentTask)
                    log.info("Breez SDK connected successfully")
                    if let breezSdk = self.lightningSession?.lightBridge?.breezSdk {
                        currentTask.start(breezSDK: breezSdk)
                    }
                } catch {
                    log.error("Breez SDK connection failed \(error)")
                    Task { await self.shutdown() }
                }
            }
        }
    }
    
    func getCredentials() throws -> Credentials {
        log.trace("restoreMnemonic")
        let lightningShortcutsAccounts = AccountsRepository.shared.accounts.compactMap { $0.getDerivedLightningAccount() }
        guard let account = lightningShortcutsAccounts.first else {
            throw SdkError.Generic(message: "Wallet not found")
        }
        return try AuthenticationTypeHandler.getAuthKeyCredentials(forNetwork: account.keychain)
    }
    
    func breezConnect(credentials: Credentials, listener: EventListener) async throws {
        self.lightningSession = LightningSessionManager(NetworkSecurityCase.bitcoinSS.gdkNetwork)
        self.lightningSession?.listener = listener
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
        log.info("Notification payload: \(content.userInfo)")
        log.info("Notification type: \(notificationType)")
        
        switch(notificationType) {
            case "payment_received":
            log.info("creating task for payment received")
            return PaymentReceiverTask(logger: log, contentHandler: contentHandler, bestAttemptContent: bestAttemptContent)
        case "lnurlpay_info":
            guard let messageData = content.userInfo["notification_payload"] as? String else {
                contentHandler!(content)
                return nil
            }
            log.info("lnurlpay_info data string: \(messageData)")
            let jsonData = messageData.data(using: .utf8)!
            do {
                let lnurlInfoMessage: LnurlInfoMessage = try JSONDecoder().decode(LnurlInfoMessage.self, from: jsonData)
                
                log.info("creting lnurl pay task, payload: \(lnurlInfoMessage.stringify() ?? "")")
                return LnurlPayInfo(message: lnurlInfoMessage, logger: log, contentHandler: contentHandler, bestAttemptContent: bestAttemptContent)
            } catch let e {
                log.info("Error in parsing request: \(e)")
                return nil
            }
        case "lnurlpay_invoice":
            guard let messageData = content.userInfo["notification_payload"] as? String else {
                contentHandler!(content)
                return nil
            }
            log.info("lnurlpay_invoice data string: \(messageData)")
            let jsonData = messageData.data(using: .utf8)!
            do {
                let lnurlInvoiceMessage: LnurlInvoiceMessage = try JSONDecoder().decode(LnurlInvoiceMessage.self, from: jsonData)

                log.info("creting lnurl pay task, payload: \(lnurlInvoiceMessage.stringify() ?? "")")
                return LnurlPayInvoice(message: lnurlInvoiceMessage, logger: log, contentHandler: contentHandler, bestAttemptContent: bestAttemptContent)
            } catch let e {
                log.info("Error in parsing request: \(e)")
                return nil
            }
        default:
            return nil
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        log.info("serviceExtensionTimeWillExpire()")
        
        // iOS calls this function just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content,
        // otherwise the original push payload will be used.
        Task { await self.shutdown() }
    }
    
    private func shutdown() async -> Void {
        log.info("shutting down...")
        try? await breezDisconnect()
        log.info("task unregistered")
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
            logger.debug("greenlight: [\(l.level)] \(l.line)")
        }
    }
}

