//
//  SendTableViewControllerScene.swift
//  gaios
//

import UIKit

class SendAmountTableCell: UITableViewCell {
}

class SendToTableCell: UITableViewCell {
}

class SendFeeChoiceTableCell: UITableViewCell {

    @IBOutlet weak var feeChoice: UISegmentedControl!

    override func awakeFromNib() {
        let attr = NSDictionary(object: UIFont.systemFont(ofSize: 9), forKey: NSAttributedStringKey.font as NSCopying)
        feeChoice.setTitleTextAttributes(attr as [NSObject : AnyObject] , for: .normal)
    }
}

class SendTableViewControllerScene: UITableViewController {
    let cellIdentifiers = ["SendAmountTableCell", "SendToTableCell", "SendFeeChoiceTableCell"]

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.tableHeaderView = UIView()
        tableView.tableFooterView = UIView()
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Main"
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cellIdentifiers.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifiers[indexPath.row], for: indexPath)
        return cell
    }
}
