import Foundation
import UIKit

class DenominationSelectorViewController : UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    let denominations: [String] = [SettingsStore.shared.denominationPrimary, SettingsStore.shared.denominationMilli, SettingsStore.shared.denominationMicro]
    @IBOutlet weak var topLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        topLabel.text = NSLocalizedString("id_denomination", comment: "")
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return 45
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return denominations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CurrencyCell", for: indexPath) as! DenominationCell
        let currency = denominations[indexPath.row]
        cell.leftLabel.text = currency
        if (currency == SettingsStore.shared.getDenominationSettings()) {
            cell.rightImageView.isHidden = false
        } else {
            cell.rightImageView.isHidden = true
        }
        cell.selectionStyle = .none
        cell.separatorInset = UIEdgeInsetsMake(0, 16, 0, 16)
        return cell;
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let currency = denominations[indexPath.row]
        SettingsStore.shared.setDenominationSettings(denomination: currency)
        tableView.reloadData()
    }
}
