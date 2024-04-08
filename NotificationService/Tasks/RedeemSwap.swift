import UserNotifications
import Foundation
import BreezSDK
import os.log
import core

struct AddressTxsConfirmedRequest: Codable {
    let address: String
}

class RedeemSwapTask : TaskProtocol {
    static let NOTIFICATION_THREAD_SWAP_TX_CONFIRMED = "SWAP_TX_CONFIRMED"
    
    internal var payload: String
    internal var contentHandler: ((UNNotificationContent) -> Void)?
    internal var bestAttemptContent: UNMutableNotificationContent?
    internal var dismiss: (() -> Void)?
    internal var swapAddress: String? = nil
    
    init(payload: String, logger: Logger, contentHandler: ((UNNotificationContent) -> Void)? = nil, bestAttemptContent: UNMutableNotificationContent? = nil, dismiss: (() -> Void)? = nil) {
        self.payload = payload
        self.contentHandler = contentHandler
        self.bestAttemptContent = bestAttemptContent
        self.dismiss = dismiss
    }
    
    public func onEvent(e: BreezEvent) {
        if let address = self.swapAddress {
            switch e {
            case .swapUpdated(details: let swapInfo):
                logger.info("Received swap updated event: \(swapInfo.bitcoinAddress), current address: \(address) status: \(swapInfo.status.hashValue)")
                if address == swapInfo.bitcoinAddress {
                    if (swapInfo.paidMsat > 0) {
                        logger.info("Swap address \(swapInfo.bitcoinAddress) redeemed succesfully")
                        self.displayPushNotification(title: "Swap Confirmed", threadIdentifier: RedeemSwapTask.NOTIFICATION_THREAD_SWAP_TX_CONFIRMED)
                    }
                }
                self.dismiss?()
                break
            default:
                break
            }
        }
    }
    
    func start(breezSDK: BlockingBreezServices) throws {
        do {
            let addressTxsConfirmedRequest = try JSONDecoder().decode(AddressTxsConfirmedRequest.self, from: self.payload.data(using: .utf8)!)
            swapAddress = addressTxsConfirmedRequest.address
        } catch let e {
            logger.error("Failed to decode payload: \(e, privacy: .public)")
            throw e
        }
        
        guard let address = swapAddress else {
            logger.error("Failed to process swap notification: swap address not in payload")
            throw NotificationError.InvalidNotification
        }
        
        do {
            try breezSDK.redeemSwap(swapAddress: address)
            logger.debug("Found swap for \(address, privacy: .public)")
            self.dismiss?()
        } catch let e {
            logger.error("Failed to manually redeem swap notification: \(e, privacy: .public)")
            throw e
        }
    }

    func onShutdown() {
        self.displayPushNotification(title: "Open the app to complete swap", threadIdentifier: RedeemSwapTask.NOTIFICATION_THREAD_SWAP_TX_CONFIRMED)
    }
}
