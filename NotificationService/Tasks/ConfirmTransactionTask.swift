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
                logger.info("\(self.TAG, privacy: .public): Received reverse swap updated event: \(revSwapInfo.id, privacy: .public), current address: \(address) status: \(revSwapInfo.status.description(), privacy: .public)")
                if .completedSeen == revSwapInfo.status, .completedConfirmed == revSwapInfo.status {
                    self.notifySuccess()
                    self.dismiss?()
                }
            case .swapUpdated(details: let swapInfo):
                logger.info("\(self.TAG, privacy: .public): Received swap updated event: \(swapInfo.bitcoinAddress, privacy: .public), current address: \(address, privacy: .public) status: \(swapInfo.status.description(), privacy: .public)")
                
                if address == swapInfo.bitcoinAddress {
                    if (swapInfo.paidMsat > 0) {
                        logger.info("\(self.TAG, privacy: .public): Swap address \(swapInfo.bitcoinAddress, privacy: .public) redeemed succesfully")
                        self.notifySuccess()
                        self.dismiss?()
                    }
                }
            case .invoicePaid(details: let details):
                logger.info("\(self.TAG, privacy: .public): Received payment. Bolt11: \(details.bolt11, privacy: .public)\nPayment Hash:\(details.paymentHash, privacy: .public)")
            case .synced:
                logger.info("\(self.TAG, privacy: .public): Received synced event")
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
            logger.error("\(self.TAG, privacy: .public): Failed to decode payload: \(e, privacy: .public)")
            throw e
        }

        guard let address = bitcoinAddress else {
            logger.error("\(self.TAG, privacy: .public): Address not in payload")
            throw NotificationError.InvalidNotification
        }

        do {
            try breezSDK.redeemSwap(swapAddress: address)
            logger.info("\(self.TAG, privacy: .public): Found swap for \(address, privacy: .public)")
            self.dismiss?()
            return
        } catch let e {
            logger.error("\(self.TAG, privacy: .public): Failed to redeem swap: \(e, privacy: .public)")
        }
        
        do {
            try breezSDK.claimReverseSwap(lockupAddress: address)
            logger.info("\(self.TAG, privacy: .public): Found reverse swap for \(address, privacy: .public)")
        } catch let e {
            logger.error("\(self.TAG, privacy: .public): Failed to process reverse swap: \(e, privacy: .public)")
        }
    }

    func notifySuccess() { // silent notification
        //self.displayPushNotification(title: SWAP_TX_CONFIRMED_NOTIFICATION_TITLE, threadIdentifier: TAG)
    }

    func onShutdown() { // silent notification
        //self.displayPushNotification(title: SWAP_TX_CONFIRMED_NOTIFICATION_FAILURE_TITLE, threadIdentifier: TAG)
    }
}
