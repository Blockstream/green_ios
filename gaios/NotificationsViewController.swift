import Foundation
import UIKit
import PromiseKit


class NotificationsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    var items = [NotificationItem]()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateViewModel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "NotificationTableCell", bundle: nil)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        tableView.register(nib, forCellReuseIdentifier: "NotificationCell")
        tableView.allowsSelection = false
        tableView.separatorColor = UIColor.customTitaniumLight()
        updateViewModel()
        NotificationStore.shared.refreshNotifications = {
            self.updateViewModel()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(self.notificationChanged(_:)), name: NSNotification.Name(rawValue: "notificationChanged"), object: nil)
    }

    @objc func notificationChanged(_ notification: NSNotification) {
        updateViewModel()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        let item = items[indexPath.row]
        let widthContraint = self.tableView.frame.size.width - 84
        let height = textForNotification(notification: item).heightWithConstrainedWidth(width: widthContraint, font: UIFont.systemFont(ofSize: 12, weight: .light))
        let total = 88 + height + 40
        return total
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func textForNotification(notification: NotificationItem) -> String {
        if (notification.type == "warning") {
            if (notification.id == "warninghash1") {
                return NotificationStore.shared.warrningNoTwoFactor
            } else {
                return NotificationStore.shared.warrningOneTwoFactor
            }
        } else if (notification.type == "incoming") {
            let localized = NSLocalizedString("id_you_have_received_s", comment: "")
            return String(format: localized, String.formatBtc(satoshi: notification.satoshi))
        } else if (notification.type == "outgoing") {
            let localized = NSLocalizedString("id_your_s_sent_to_s_has_been", comment: "")
            return String(format: localized, String.formatBtc(satoshi: notification.satoshi), notification.address)
        } else if (notification.type == "welcome") {
            return NSLocalizedString("id_thank_you_for_downloading_green", comment: "")
        }
        return ""
    }

    func titleForNotification(notification: NotificationItem) -> String {
        if (notification.type == "warning") {
            return NSLocalizedString("id_warning", comment: "")
        } else if (notification.type == "incoming") {
            return NSLocalizedString("id_deposit", comment: "")
        } else if (notification.type == "outgoing") {
            return NSLocalizedString("id_confirmation", comment: "")
        } else if (notification.type == "welcome") {
            return NSLocalizedString("id_welcome", comment: "")
        }
        return ""
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationCell", for: indexPath) as! NotificationTableCell
        let item: NotificationItem = items.reversed()[indexPath.row]
        cell.mainText.text = textForNotification(notification: item)
        if(item.isWarning) {
            cell.title.textColor = UIColor.red
        } else {
            cell.title.textColor = UIColor.white
        }
        cell.title.text = titleForNotification(notification: item)
        cell.date.text = NotificationStore.shared.dateToText(date: item.date)
        cell.date.sizeToFit()
        cell.title.sizeToFit()
        NotificationStore.shared.setSeen(id: item.id)
        cell.separatorInset = UIEdgeInsetsMake(0, 42, 0, 16)
        return cell;

    }

    func updateViewModel() {
        items = NotificationStore.shared.getNotifications()
        tableView.reloadData()
    }
}
