import UserNotifications
import BreezSDK

extension UNMutableNotificationContent {
    
    func fillForReceivedPayments(payments: [Payment]) {
        var msat: UInt64 = 0
        for paymentInfo in payments {
            msat += paymentInfo.amountMsat
        }
        
        var amountSat = Double(msat) / Double(1000)
        
        if payments.count == 1 {
            self.title = NSLocalizedString("Received payment", comment: "Push notification title")
            
            let payment = payments.first!
            if let desc = payment.description, desc.count > 0 {
                self.body = "\(amountSat) sats: \(desc)"
            }
        } else {
            self.title = NSLocalizedString("Received multiple payments", comment: "Push notification title")
            
            self.body = String(format: "%f sats", amountSat)
        }
        self.badge = NSNumber(value: payments.count)
    }
}
