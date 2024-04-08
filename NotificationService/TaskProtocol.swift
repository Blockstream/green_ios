import UserNotifications
import BreezSDK

public protocol TaskProtocol : EventListener {
    var payload: String { get set }
    var contentHandler: ((UNNotificationContent) -> Void)? { get set }
    var bestAttemptContent: UNMutableNotificationContent? { get set }
    var dismiss: (() -> Void)? { get set }
    
    func start(breezSDK: BlockingBreezServices) throws
    func onShutdown()
}

extension TaskProtocol {
    func displayPushNotification(title: String, threadIdentifier: String? = nil) {
        guard
            let contentHandler = contentHandler,
            let bestAttemptContent = bestAttemptContent
        else {
            return
        }
        
        if threadIdentifier != nil {
            bestAttemptContent.threadIdentifier = threadIdentifier!
        }
        
        bestAttemptContent.title = title
        contentHandler(bestAttemptContent)
    }
}
