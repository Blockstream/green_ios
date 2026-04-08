import Foundation
import greenaddress
import gdk

public enum EventNotificationTypes {
    case newBlock(blockheight: UInt32)
    case newSubaccount(subaccount: SubaccountEvent)
    case newTransaction(transaction: TransactionEvent)
    case twoFactorReset
    case updateSettings(settings: Settings)
    case disconnected
    case reconnected
    case tor(data: TorNotification)
    case refreshAssets
    case invoicePaid
    case paymentSucceed
    case paymentFailed
}

public protocol NewNotificationDelegate {
    func didReceive(event: EventNotificationTypes, networkType: NetworkSecurityCase)
}
