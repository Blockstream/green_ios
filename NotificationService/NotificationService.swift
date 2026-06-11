import Foundation
import UserNotifications
import core

struct LnurlInfoMessage: Codable {
    let callback_url: String
    let reply_url: String
}

struct LnurlInvoiceMessage: Codable {
    let reply_url: String
    let amount: UInt64
}

public enum NotificationType: String, Codable {
    case addressTxsConfirmed = "address_txs_confirmed"
    case paymentReceived = "payment_received"
    case swapUpdated = "swap_updated"
    case boltzEvent = "BOLTZ_EVENT"
}

public enum NotificationError: Error {
    case InvalidNotification
    case InvalidSwap
    case WalletNotFound
    case Failed
    case EventNotFound
    case Timeout
}

enum NotificationEvent {
    case meld(MeldEvent)
    case lightning(LightningEvent)
    case lwk(LwkEvent)

    static func from(userInfo: [AnyHashable: Any]) -> NotificationEvent? {
        if let notification = LightningEvent.from(userInfo) as? LightningEvent {
            return NotificationEvent.lightning(notification)
        } else if let notification = MeldEvent.from(userInfo) as? MeldEvent {
            return NotificationEvent.meld(notification)
        } else if let notification = LwkEvent.from(userInfo) as? LwkEvent {
            return NotificationEvent.lwk(notification)
        }
        return nil
    }
}


class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    private var activeTask: Task<Void, Never>?
    private var notificationEvent: NotificationEvent?
    private var isFinished = false

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void)
    {
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        guard let userInfo = bestAttemptContent?.userInfo else {
            logger.info("NotificationService: Invalid data")
            contentHandler(bestAttemptContent ?? request.content)
            return
        }
        logger.info("NotificationService: Notification received: \(userInfo.stringify() ?? "", privacy: .public)")
        notificationEvent = NotificationEvent.from(userInfo: userInfo)
        switch notificationEvent {
        case .lightning(let notification):
            activeTask = Task(priority: .userInitiated) { [weak self] in
                await self?.didReceiveLightning(notification)
                self?.activeTask = nil
                await self?.showNotification()
            }
        case .meld(let notification):
            activeTask = Task(priority: .userInitiated) { [weak self] in
                await self?.didReceiveMeld(notification)
                self?.activeTask = nil
                await self?.showNotification()
            }
        case .lwk(let notification):
            activeTask = Task(priority: .userInitiated) { [weak self] in
                await self?.didReceiveLwkSwap(notification)
                self?.activeTask = nil
                await self?.showNotification()
            }
        default:
            logger.info("NotificationService: Invalid notification")
            contentHandler(bestAttemptContent ?? request.content)
        }
    }

    func didReceiveLwkSwap(_ notification: LwkEvent) async {
        let eventData = notification.data.replacingOccurrences(of: "'", with: "\"")
        guard let eventSwap = LwkEventData.from(string: eventData) as? LwkEventData else {
            return
        }
        guard await SwapManager.shared.shouldStartTask(for: eventSwap.id) else {
            logger.info("Duplicate swap \(eventSwap.id) ignored.")
            return
        }
        defer {
            Task { await SwapManager.shared.finishTask(for: eventSwap.id) }
        }
        
        do {
            guard let account = getAccount(xpub: notification.walletHashedId),
            let xpubHashId = account.xpubHashId else {
                throw NotificationError.WalletNotFound
            }
            // Pre-update UI notification
            bestAttemptContent?.title = account.name
            bestAttemptContent?.threadIdentifier = account.xpubHashId ?? ""
            if let persistentId = try await BoltzController.shared.fetchID(byId: eventSwap.id),
                  let swap = try await BoltzController.shared.get(with: persistentId) {
                switch eventSwap.status {
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
                    break
                }
            }
            // get credentials
            let credentials = try AuthenticationTypeHandler.getCredentials(method: .AuthKeyBoltz, for: account.keychain)
            guard let mnemonic = credentials.mnemonic else {
                throw NotificationError.Failed
            }
            // get session and start task iteration
            let sharedSession = await SwapManager.shared.getSession(for: xpubHashId)
            let task = SwapTask(session: sharedSession)
            let swap = try await task.start(xpubHashId: xpubHashId, secret: mnemonic, swapId: eventSwap.id)
        } catch NotificationError.Timeout {
            logger.error("NotificationService timeout error")
        } catch {
            logger.error("NotificationService error: \(error.localizedDescription, privacy: .public)")
        }
    }

    func didReceiveMeld(_ notification: MeldEvent) async {
        do {
            guard let externalCustomerId = notification.payload.externalCustomerId else {
                throw NotificationError.InvalidNotification
            }
            guard let account = getAccount(xpub: externalCustomerId),
            let xpubHashId = account.xpubHashId else {
                throw NotificationError.WalletNotFound
            }
            bestAttemptContent?.title = account.name
            bestAttemptContent?.threadIdentifier = account.xpubHashId ?? ""
            let res = try await MeldTransactionTask().start(event: notification)
            if let body = res["body"] as? String {
                bestAttemptContent?.body = body
            }
            bestAttemptContent?.userInfo = res
        } catch {
            logger.error("NotificationService error: \(error.localizedDescription, privacy: .public)")
        }
    }

    func didReceiveLightning(_ notification: LightningEvent) async {
        do {
            guard let xpub = notification.walletHashedId else {
                throw NotificationError.InvalidNotification
            }
            logger.info("NotificationService: xpub: \(xpub, privacy: .public)")
            
            guard let account = getAccount(xpub: xpub),
                  let xpubHashId = account.xpubHashId else {
                throw NotificationError.WalletNotFound
            }
            
            bestAttemptContent?.title = account.name
            bestAttemptContent?.threadIdentifier = xpubHashId
            bestAttemptContent?.body = notification.displayMessage ?? "Lightning is running in the background"
            
            #if DEBUG
            let canWakeSigner = true
            #else
            let canWakeSigner = (notification.eventType == .incomingPayment)
            #endif
            
            if canWakeSigner {
                logger.info("NotificationService: Using lightning wallet \(account.name, privacy: .public)")
                let keychainLightning = account.keychainLightning
                let credentials = try AuthenticationTypeHandler.getCredentials(method: .AuthKeyLightning, for: keychainLightning)
                guard let mnemonic = credentials.mnemonic else {
                    throw NotificationError.Failed
                }
                
                let task = LightningTask()
                try await task.start(xpubHashId: xpubHashId, secret: mnemonic)
            } else {
                logger.info("NotificationService: Event \(notification.eventType.rawValue, privacy: .public) handled")
            }
        } catch {
            logger.error("NotificationService error: \(error.localizedDescription, privacy: .public)")
        }
    }

    func getAccount(xpub: String) -> Account? {
        let accounts = AccountsRepository.shared.accounts
        return accounts
            .filter { $0.xpubHashId == xpub }
            .first
    }

    override func serviceExtensionTimeWillExpire() {
        logger.info("NotificationService: serviceExtensionTimeWillExpire()")
        activeTask?.cancel()
        Task { @MainActor in
            if isFinished { return }
            switch notificationEvent {
            case .meld:
                bestAttemptContent?.body = "Buy. Open app to resume."
            case .lightning:
                bestAttemptContent?.body = "Lightning pay. Open app to resume."
            case .lwk:
                bestAttemptContent?.body = "Swap. Open app to resume."
            case nil:
                break
            }
            showNotification()
            self.shutdown()
        }
    }

    private func shutdown() -> Void {
        Task.detached(priority: .high) { @MainActor [weak self] in
            logger.info("NotificationService: shutting down...")
            logger.info("NotificationService: task unregistered")
        }
    }

    @MainActor
    func showNotification() {
        if let bestAttemptContent, !isFinished {
            contentHandler?(bestAttemptContent)
            contentHandler = nil
            isFinished = true
        }
    }
}
