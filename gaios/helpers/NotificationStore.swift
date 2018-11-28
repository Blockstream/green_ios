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
    let warrningNoTwoFactor = NSLocalizedString("id_your_wallet_is_not_yet_fully", comment: "")
    let warrningOneTwoFactor = NSLocalizedString("id_you_only_have_one_twofactor", comment: "")

    // FIXME: delete this code or coalesce into existing one
    func getTransactions() {
        AccountStore.shared.getWallets(cached: true).done { wallets in
            for wallet in wallets {
                wrap{ try getSession().getTransactions(subaccount: wallet.pointer, page: 0)
                    }.done { (transactions: [String: Any]?) in
                        let list = transactions!["list"] as! NSArray
                        for tx in list {
                            print(tx)
                            let transaction = tx as! [String : Any]
                            let blockHeight = transaction["block_height"] as! UInt32
                            if (AccountStore.shared.getBlockheight() - blockHeight < 1) {
                                continue
                            }
                            let satoshi:UInt64 = transaction["satoshi"] as! UInt64
                            let hash = transaction["txhash"] as! String
                            let dateString = transaction["created_at"] as! String
                            let date = Date.dateFromString(dateString: dateString)
                            let type = transaction["type"] as! String
                            if (type == "redeposit") {
                                return
                            }
                            let adressees = transaction["addressees"] as! [String]
                            var counterparty = ""
                            if (adressees.count > 0) {
                                counterparty = adressees[0]
                            }
                            let note: NotificationItem = NotificationItem(date: date, id: hash, seen: false, isWarning: false, satoshi: satoshi, type: type, address: counterparty)
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
        }
    }

    func writeNotificationsToDisk() {
        guard let url = Storage.getDocumentsURL()?.appendingPathComponent(Storage.getNotificationPath()) else {
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
        guard let url = Storage.getDocumentsURL()?.appendingPathComponent(Storage.getNotificationPath()) else {
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
        return Array(allNotifications.values).sorted(by: { $0.date.timeIntervalSince1970 < ($1.date.timeIntervalSince1970) })
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

    func createWelcomeNotification() -> NotificationItem {
        let date = Date()
        let localizedTitle = NSLocalizedString("id_welcome", comment: "")
        let localizedMessage = NSLocalizedString("id_thank_you_for_downloading_green", comment: "")
        return NotificationItem(date: date, id: "welcomehash", seen: false, isWarning: false, satoshi: 0, type: "welcome", address: "")
    }

    func createWarningNotification() -> NotificationItem? {
        let date = Date()
        if (!AccountStore.shared.isTwoFactorEnabled()) {
            return NotificationItem(date: date.addingTimeInterval(date.timeIntervalSince1970), id: "warninghash1", seen: false, isWarning: true, satoshi: 0, type: "warning", address: "")
        } else if (AccountStore.shared.twoFactorsEnabledCount() == 1) {
            return NotificationItem(date: date.addingTimeInterval(date.timeIntervalSince1970), id: "warninghash2", seen: false, isWarning: true, satoshi: 0, type: "warning", address: "")
        }
        return nil
    }

    func removeWarning() {

    }

    func maybeAddWarningNotification() {
        if let warning = createWarningNotification() {
            allNotifications.removeValue(forKey: warning.id)
            allNotifications[warning.id] = warning
            self.newNotificationCount += 1
            writeNotificationsToDisk()
        }
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

    func initializeNotificationStore() {
        allNotifications = loadNotificationsFromDisk()
        maybeAddWelcomeNotification()
        maybeAddWarningNotification()
        refreshNotifications?()
        getTransactions()
    }

    let walletTransactions: [UInt32: Array<NotificationItem>] =  [UInt32: Array<NotificationItem>]()

}


class NotificationItem: Codable{
    var date: Date
    var id: String
    var seen: Bool
    var isWarning: Bool
    var satoshi: UInt64
    var type: String
    var address: String

    init(date: Date, id: String, seen: Bool, isWarning: Bool, satoshi: UInt64, type: String, address: String) {
        self.date = date
        self.id = id
        self.seen = seen
        self.isWarning = isWarning
        self.satoshi = satoshi
        self.type = type
        self.address = address
    }
}

protocol NotificationDelegate: class {
    func newNotification()
    func dismissNotification()
    func notificationChanged()
}
