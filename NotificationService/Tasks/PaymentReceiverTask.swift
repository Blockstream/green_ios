//
//  ReceivePayment.swift
//  Breez Notification Service Extension
//
//  Created by Roei Erez on 03/01/2024.
//
import UserNotifications
import Combine
import os.log
import notify
import Foundation
import BreezSDK

class PaymentReceiverTask : SDKBackgroundTask {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?
    private var logger: Logger
    private var receivedPayment: Payment? = nil
    
    init(logger: Logger, contentHandler: ((UNNotificationContent) -> Void)? = nil, bestAttemptContent: UNMutableNotificationContent? = nil) {
        self.contentHandler = contentHandler
        self.bestAttemptContent = bestAttemptContent
        self.logger = logger
    }
    
    func start(breezSDK: BlockingBreezServices){}
    
    func onShutdown() {
        let title = self.receivedPayment != nil ? "Received \(self.receivedPayment!.amountMsat/1000) sats" :  "Receive payment failed"
        self.displayPushNotification(title: title)
    }
    
    func onEvent(e: BreezEvent) {
        switch e {
        case .invoicePaid(details: let details):
            self.logger.info("Received payment. Bolt11: \(details.bolt11)\nPayment Hash:\(details.paymentHash)")
            receivedPayment = details.payment
            break
        case .synced:
            self.logger.info("got synced event")
            if let p =  self.receivedPayment {
                self.onShutdown()
            }
            break
        default:
            break
        }
    }
    
    
    public func displayPushNotification(title: String) {
        self.logger.info("displayPushNotification \(title)")
        
        
        guard
            let contentHandler = contentHandler,
            let bestAttemptContent = bestAttemptContent
        else {
            return
        }

        bestAttemptContent.title = title
        contentHandler(bestAttemptContent)
    }
}
