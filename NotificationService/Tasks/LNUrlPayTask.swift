//
//  LnurlPay.swift
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

// Response for the first message of Lnurlpay.
struct LnurlInfo: Decodable, Encodable {
    let callback: String
    let maxSendable: UInt64
    let minSendable: UInt64
    let metadata: String
    let tag: String
    
    init(callback: String, maxSendable: UInt64, minSendable: UInt64, metadata: String, tag: String) {
        self.callback = callback
        self.maxSendable = maxSendable
        self.minSendable = minSendable
        self.metadata = metadata
        self.tag = tag
    }
}

// Response for the second message of Lnurlpay.
struct LnurlInvoiceResponse: Decodable, Encodable {
    let pr: String
    let routes: [String]
    
    init(pr: String, routes: [String]) {
        self.pr = pr
        self.routes = routes
    }
}

// Error Lnurl response.
struct LnurlErrorResponse: Decodable, Encodable {
    let status: String
    let reason: String
    
    init(status: String, reason: String) {
        self.status = status
        self.reason = reason
    }
}

// Base class for Lnurlpay protocol messages
class LnurlPayTask {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    var logger: Logger
    var successNotifiationTitle: String
    var failNotificationTitle: String
    
    init(logger: Logger, contentHandler: ((UNNotificationContent) -> Void)? = nil, bestAttemptContent: UNMutableNotificationContent? = nil, successNotificationTitle: String, failNotificationTitle: String) {
        self.contentHandler = contentHandler
        self.bestAttemptContent = bestAttemptContent
        self.logger = logger
        self.successNotifiationTitle = successNotificationTitle;
        self.failNotificationTitle = failNotificationTitle;
    }
    
    func onEvent(e: BreezEvent) {}
    
    func onShutdown() {
        displayPushNotification(title: self.failNotificationTitle)
    }
    
    func replyServer(encodable: Encodable, replyURL: String) {
        guard let serverReplyURL = URL(string: replyURL) else {
            self.displayPushNotification(title: self.failNotificationTitle)
            return
        }
        var request = URLRequest(url: serverReplyURL)
        request.httpMethod = "POST"
        request.httpBody = try! JSONEncoder().encode(encodable)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            let statusCode = (response as? HTTPURLResponse)?.statusCode

            if statusCode == 200 {
                self.displayPushNotification(title: self.successNotifiationTitle)
            } else {
                self.displayPushNotification(title: self.failNotificationTitle)
                return
            }
        }
        task.resume()
    }
    
    func fail(withError: String, replyURL: String) {
        guard let serverReplyURL = URL(string: replyURL) else {
            self.displayPushNotification(title: self.failNotificationTitle)
            return
        }
        var request = URLRequest(url: serverReplyURL)
        request.httpMethod = "POST"
        request.httpBody = try! JSONEncoder().encode(LnurlErrorResponse(status: "ERROR", reason: withError))
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            let res = response as? HTTPURLResponse
            self.logger.info("\(serverReplyURL) \(res?.statusCode ?? 0)")
        }
        task.resume()
        self.displayPushNotification(title: self.failNotificationTitle)
    }
    
    func displayPushNotification(title: String) {
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

// Class that handles the first message of lnurl pay.
class LnurlPayInfo : LnurlPayTask, SDKBackgroundTask {
    private var message: LnurlInfoMessage
    
    init(message: LnurlInfoMessage, logger: Logger, contentHandler: ((UNNotificationContent) -> Void)? = nil, bestAttemptContent: UNMutableNotificationContent? = nil) {
        self.message = message
        super.init(logger: logger, contentHandler: contentHandler, bestAttemptContent: bestAttemptContent, successNotificationTitle: "Retrieving payment information", failNotificationTitle: "Receive Payment Failed")
    }
    
    func start(breezSDK: BlockingBreezServices){
        do {
            let metadata = "[[\"text/plain\",\"Pay to Breez\"]]"
            let nodeInfo = try breezSDK.nodeInfo()
            replyServer(encodable: LnurlInfo(callback: message.callback_url, maxSendable: nodeInfo.inboundLiquidityMsats, minSendable: UInt64(1000), metadata: metadata, tag: "payRequest"),
                replyURL: message.reply_url)
        } catch let e {
            self.logger.error("failed to process lnurl: \(e)")
            fail(withError: e.localizedDescription, replyURL: message.reply_url)
        }
    }
}

// Class that handles the second message of lnurl pay.
class LnurlPayInvoice : LnurlPayTask, SDKBackgroundTask {
    private var message: LnurlInvoiceMessage
    
    init(message: LnurlInvoiceMessage, logger: Logger, contentHandler: ((UNNotificationContent) -> Void)? = nil, bestAttemptContent: UNMutableNotificationContent? = nil) {
        self.message = message
        super.init(logger: logger, contentHandler: contentHandler, bestAttemptContent: bestAttemptContent, successNotificationTitle: "Fetching invoice", failNotificationTitle: "Receive Payment Failed")
    }
    
    func start(breezSDK: BlockingBreezServices){
        do {
            let metadata = "[[\"text/plain\",\"Pay to Breez\"]]"
            let nodeInfo = try breezSDK.nodeInfo()
            if message.amount < 1000 || message.amount > nodeInfo.inboundLiquidityMsats {
                fail(withError: "Invalid amount requested \(message.amount)", replyURL: message.reply_url)
                return
            }
            let receiveResponse = try breezSDK.receivePayment(req: ReceivePaymentRequest(amountMsat: message.amount, description: metadata, useDescriptionHash: true))
            self.replyServer(encodable: LnurlInvoiceResponse(pr: receiveResponse.lnInvoice.bolt11, routes: []), replyURL: message.reply_url)
        } catch let e {
            self.logger.error("failed to process lnurl: \(e)")
            self.fail(withError: e.localizedDescription, replyURL: message.reply_url)
        }
    }
}

