//
//  NotificationStore.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/15/18.
//  Copyright © 2018 Blockstream inc. All rights reserved.
//

import Foundation

class NotificationStore {

    static let shared = NotificationStore()
    var delegate: NotificationDelegate?
    var refreshNotifications: (()->())?

    private init() { }
    
    var notifications: [String: NotificationItem] = [String: NotificationItem]()
    var localNotification: [String: NotificationItem] = [String: NotificationItem]()
    var allNotifications: [String: NotificationItem] = [String: NotificationItem]()
    var newNotificationCount = 0

    func getTransactions() {
        AccountStore.shared.getWallets().done { (wallets: Array<WalletItem>) in
            for wallet in wallets {
                wrap{ try getSession().getTransactions(subaccount: wallet.pointer, page: 0)
                    }.done { (transactions: [String: Any]?) in
                        let list = transactions!["list"] as! NSArray
                        for tx in list {
                            print(tx)
                            let transaction = tx as! [String : Any]
                            let satoshi:Int = transaction["satoshi"] as! Int
                            let hash = transaction["txhash"] as! String
                            let dateString = transaction["created_at"] as! String
                            let date = Date.dateFromString(dateString: dateString)
                            let type = transaction["type"] as! String
                            if(type == "outgoing") {
                                print(tx)
                                print("blah")
                            }
                            let adressees = transaction["addressees"] as! [String]
                            var counterparty = ""
                            if (adressees.count > 0) {
                                counterparty = adressees[0]
                            }
                            let note: NotificationItem = self.createNotification(date: date, hash: hash, amount: satoshi, counterparty: counterparty, type: type)
                            if (self.allNotifications[hash] == nil) {
                                self.allNotifications[hash] = note
                                self.newNotificationCount += 1
                                self.delegate?.newNotification()
                                self.writeNotificationsToDisk()
                                self.refreshNotifications?()
                            }
                        }
                    }.catch {error in
                        print("error getting transaction")
                }
            }
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

    func setSeen(id: String) {
        guard let item = allNotifications[id] else {
            return
        }
        if (item.seen == true) {
            item.seen = false
            self.newNotificationCount -= 1
        }
        delegate?.dismissNotification()
    }

    func createWelcomeNotification() -> NotificationItem{
        let date = Date()
        return NotificationItem(date: date, title: "Welcome", text: "Thank you for downloading Green! please leave us a review when you get a chance.", id: "welcomehash", seen: false, timestamp: date.timeIntervalSince1970)
    }

    func maybeAddWelcomeNotification() {
        let welcome = createWelcomeNotification()
        if(allNotifications[welcome.id] == nil) {
            allNotifications[welcome.id] = welcome
            self.newNotificationCount += 1
            writeNotificationsToDisk()
        }
    }

    func hasNewNotifications() -> Bool{
        return newNotificationCount > 0
    }

    func createNotification(date: Date, hash: String, amount: Int, counterparty: String, type: String) -> NotificationItem {
        var title: String = ""
        var bodyText = ""
        let amountText = String.satoshiToBTC(satoshi: abs(amount))
        if(type != "outgoing") {
            title = "Deposit"
            bodyText = String(format: "You have received %@ BTC", amountText)
        } else {
            title = "Confirmation"
            bodyText = String(format: "Your  %@ BTC sent to %@ has been confirmed", amountText, counterparty)
        }
        
        return NotificationItem(date: date, title: title, text: bodyText, id: hash, seen: false, timestamp: date.timeIntervalSince1970)
    }

    func initializeNotificationStore() {
        allNotifications = loadNotificationsFromDisk()
        maybeAddWelcomeNotification()
        refreshNotifications?()
        getTransactions()
    }

    let walletTransactions: [UInt32: Array<NotificationItem>] =  [UInt32: Array<NotificationItem>]()

}


class NotificationItem: Codable{
    var title: String
    var text: String
    var date: Date
    var timestamp: Double
    var id: String
    var seen: Bool

    init(date: Date, title: String, text: String, id: String, seen: Bool, timestamp: Double) {
        self.title = title
        self.text = text
        self.date = date
        self.id = id
        self.seen = seen
        self.timestamp = timestamp
    }
}

protocol NotificationDelegate: class {
    func newNotification()
    func dismissNotification()
    func notificationChanged()
}
