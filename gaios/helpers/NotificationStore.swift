//
//  NotificationStore.swift
//  gaios
//
//  Created by Strahinja Markovic on 8/14/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//
/*
 load notification from disk
 get transactions all
 parse them to notification format
 check if newly parsed notification contain anything that's not included in old
 Notification format:
 deposit
 confirmation
 amount
 date
 id
 ////
 store notification to disk
 
 
 check if there is new notific
 */
import Foundation

class NotificationStore {

    static let shared = NotificationStore()
    
    private init() { }
    
    var notifications: [String: NotificationItem] = [String: NotificationItem]()
    var localNotification: [String: NotificationItem] = [String: NotificationItem]()
    var allNotifications: [String: NotificationItem] = [String: NotificationItem]()

    func getTransactions() {
        AccountStore.shared.getWallets().done { (wallets: Array<WalletItem>) in
            for wallet in wallets {
                wrap{ try getSession().getTransactions(subaccount: wallet.pointer)
                    }.done { (transactions:[Transaction]?, ptx: UInt32 ) in
                        for tx in transactions ?? [] {
                            let json = try! tx.toJSON()!
                            guard let val:String = json["value_str"] as? String else {
                                continue
                            }
                            let satoshi:Int = Int(val)!
                            let hash: String! = json["hash"] as! String
                            let counterparty: String = json["counterparty"] as! String
                            let timestamp = json["timestamp"] as! String
                            let note: NotificationItem = self.createNotification(timestamp: timestamp, hash: hash, amount: satoshi, counterparty: counterparty)
                            if (self.allNotifications[hash] == nil) {
                                self.allNotifications[hash] = note
                            }
                        }
                    }.catch {error in
                        print("error getting transaction")
                }
            }
            self.writeNotificationsToDisk()
        }.catch{ error in
            print("error getting wallets")
        }
    }

    func writeNotificationsToDisk() {
        guard let url = Storage.getDocumentsURL()?.appendingPathComponent("notifications.json") else {
            return
        }
        let encoder = JSONEncoder()
        do {
            let notificationsToWrite = allNotifications.values
            let data = try encoder.encode(allNotifications)
            // 3. Write this data to the url specified in step 1
            try data.write(to: url, options: [])
        } catch {
            print("error writing notifications to disk")
        }
    }
    
    func loadNotificationsFromDisk() -> [String: NotificationItem] {
        guard let url = Storage.getDocumentsURL()?.appendingPathComponent("notifications.json") else {
            return [String: NotificationItem]()
        }
        let decoder = JSONDecoder()
        do {
            // 2. Retrieve the data on the file in this path (if there is any)
            let data = try Data(contentsOf: url, options: [])
            // 3. Decode an array of Posts from this Data
            let notifications = try decoder.decode( [String: NotificationItem].self, from: data)
            return notifications
        } catch {
            return [String: NotificationItem]()
        }
    }
    
    func getNotifications() -> Array<NotificationItem> {
        return Array(allNotifications.values).sorted(by: { $0.timestamp < ($1.timestamp) })
    }

    func dateFromTimestamp(date: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.date(from: date)!
    }

    func dateToText(date: Date) -> String {
        let now = Date()
        if (now.days(from: date) < 1) {
            return "Today"
        } else if (now.days(from: date) == 1) {
            return "Yesterday"
        } else if (now.weeks(from: date) < 1) {
            return "This Week"
        } else if (now.weeks(from: date) == 1) {
            return "Last Week"
        } else if (now.months(from: date) < 1) {
            return "This Month"
        } else if (now.months(from: date) == 1) {
            return "Last Month"
        } else {
            let result = String(format: "%d Months Ago", now.months(from: date))
            return result
        }
    }

    func createNotification(timestamp: String, hash: String, amount: Int, counterparty: String) -> NotificationItem {
        let date = self.dateFromTimestamp(date: timestamp)
        let dateText = dateToText(date: date)
        var title: String = ""
        var bodyText = ""
        let amountText = String.satoshiToBTC(satoshi: abs(amount))
        if(amount > 0) {
            title = "Deposit"
            bodyText = String(format: "You have received %@ BTC from %@", amountText, counterparty)
        } else {
            title = "Confirmation"
            bodyText = String(format: "Your  %@ BTC sent to %@ has been confirmed", amountText, counterparty)
        }
        
        return NotificationItem(date: dateText, title: title, text: bodyText, id: hash, seen: false, timestamp: date.timeIntervalSince1970)
    }

    func initializeNotificationStore() {
        allNotifications = loadNotificationsFromDisk()
        
        getTransactions()
    }

    let walletTransactions: [UInt32: Array<NotificationItem>] =  [UInt32: Array<NotificationItem>]()

}


class NotificationItem: Codable{
    var title: String
    var text: String
    var date: String
    var timestamp: Double
    var id: String
    var seen: Bool

    init(date: String, title: String, text: String, id: String, seen: Bool, timestamp: Double) {
        self.title = title
        self.text = text
        self.date = date
        self.id = id
        self.seen = seen
        self.timestamp = timestamp
    }
}
