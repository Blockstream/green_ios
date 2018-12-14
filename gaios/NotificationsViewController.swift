import Foundation
import UIKit
import PromiseKit


class NotificationsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    var items: Events { get { return getGAService().getEvents() } }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        tableView.allowsSelection = false
        tableView.separatorColor = UIColor.customTitaniumLight()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadData(_:)), name: NSNotification.Name(rawValue: EventType.TwoFactorReset.rawValue), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadData(_:)), name: NSNotification.Name(rawValue: EventType.Transaction.rawValue), object: nil)
        tableView.reloadData()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: EventType.TwoFactorReset.rawValue), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: EventType.Transaction.rawValue), object: nil)
    }

    @objc func reloadData(_ notification: NSNotification) {
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {let cell =
        tableView.dequeueReusableCell(withIdentifier: "cell",
                                      for: indexPath as IndexPath)
        let event = items[indexPath.row]
        cell.textLabel!.text = event.title()
        cell.detailTextLabel!.text = event.description()
        cell.detailTextLabel!.numberOfLines = 4
        cell.selectionStyle = .none
        cell.setNeedsLayout()
        return cell;
    }
}
