//
//  TxReceiverTask.swift
//  Breez Notification Service Extension
//
//
import UserNotifications
import Combine
import os.log
import notify
import Foundation
import BreezSDK

class TxReceiverTask : SDKBackgroundTask {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?
    private var logger: Logger
    
    init(logger: Logger, contentHandler: ((UNNotificationContent) -> Void)? = nil, bestAttemptContent: UNMutableNotificationContent? = nil) {
        self.contentHandler = contentHandler
        self.bestAttemptContent = bestAttemptContent
        self.logger = logger
    }
    
    func start(breezSDK: BlockingBreezServices){}
    
    func onShutdown() {
    }
    
    func onEvent(e: BreezEvent) {
        switch e {
        case .synced:
            self.logger.info("got synced event")
            self.onShutdown()
            break
        default:
            break
        }
    }
    
    public func displayFailedPushNotification() {
        displayPushNotification(text: "Open wallet to receive a payment")
    }

    public func displayPushNotification(text: String) {
        self.logger.error("displayPushNotification \(text)")
        guard
            let contentHandler = contentHandler,
            let bestAttemptContent = bestAttemptContent
        else {
            return
        }
        bestAttemptContent.title = "Green Lightning"
        bestAttemptContent.body = text.localized
        //contentHandler(bestAttemptContent)
    }
}
