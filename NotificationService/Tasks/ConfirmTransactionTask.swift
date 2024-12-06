import UserNotifications
import Foundation
import BreezSDK
import os.log
import core

struct AddressTxsConfirmedRequest: Codable {
    let address: String
}

class ConfirmTransactionTask: TaskProtocol {

    internal var payload: String
    internal var contentHandler: ((UNNotificationContent) -> Void)?
    internal var bestAttemptContent: UNMutableNotificationContent?
    internal var dismiss: (() -> Void)?
    internal var bitcoinAddress: String? = nil
    
    var TAG: String { return String(describing: self) }
    let SWAP_TX_CONFIRMED_NOTIFICATION_FAILURE_TITLE = "Open the app to complete swap"
    let SWAP_TX_CONFIRMED_NOTIFICATION_TITLE = "Swap confirmed"

    init(payload: String, logger: Logger, contentHandler: ((UNNotificationContent) -> Void)? = nil, bestAttemptContent: UNMutableNotificationContent? = nil, dismiss: (() -> Void)? = nil) {
        self.payload = payload
        self.contentHandler = contentHandler
        self.bestAttemptContent = bestAttemptContent
        self.dismiss = dismiss
    }

    public func onEvent(e: BreezEvent) {
        if let address = self.bitcoinAddress {
            switch e {
            case .reverseSwapUpdated(details: let revSwapInfo):
                logger.info("Received reverse swap updated event: \(revSwapInfo.id), current address: \(address) status: \(revSwapInfo.status.hashValue)")
                if case .completedSeen = revSwapInfo.status, case  .completedConfirmed = revSwapInfo.status {
                    self.notifySuccess()
                }
                self.dismiss?()
            case .swapUpdated(details: let swapInfo):
                logger.info("Received swap updated event: \(swapInfo.bitcoinAddress), current address: \(address) status: \(swapInfo.status.hashValue)")
                
                if address == swapInfo.bitcoinAddress {
                    if (swapInfo.paidMsat > 0) {
                        logger.info("Swap address \(swapInfo.bitcoinAddress) redeemed succesfully")
                        self.notifySuccess()
                    }
                }
                self.dismiss?()
            default:
                break
            }
        }
    }

    func start(breezSDK: BlockingBreezServices) throws {
        do {
            let addressTxsConfirmedRequest = try JSONDecoder().decode(AddressTxsConfirmedRequest.self, from: self.payload.data(using: .utf8)!)
            bitcoinAddress = addressTxsConfirmedRequest.address
        } catch let e {
            self.onShutdown()
            logger.error("Failed to decode payload: \(e, privacy: .public)")
            throw e
        }

        guard let address = bitcoinAddress else {
            logger.error("Address not in payload")
            self.onShutdown()
            throw NotificationError.InvalidNotification
        }

        do {
            try breezSDK.redeemSwap(swapAddress: address)
            logger.info("Found swap for \(address, privacy: .public)")
            self.dismiss?()
            return
        } catch let e {
            logger.error("Failed to redeem swap: \(e, privacy: .public)")
        }
        
        do {
            try breezSDK.claimReverseSwap(lockupAddress: address)
            logger.info("Found reverse swap for \(address, privacy: .public)")
        } catch let e {
            logger.error("Failed to process reverse swap: \(e, privacy: .public)")
        }
    }

    func notifySuccess() {
        self.displayPushNotification(title: SWAP_TX_CONFIRMED_NOTIFICATION_TITLE, threadIdentifier: TAG)
    }

    func onShutdown() {
        self.displayPushNotification(title: SWAP_TX_CONFIRMED_NOTIFICATION_FAILURE_TITLE, threadIdentifier: TAG)
    }
}
