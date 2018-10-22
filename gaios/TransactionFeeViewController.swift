import Foundation
import UIKit

class TransactionFeeViewController : UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {

    @IBOutlet weak var tableView: UITableView!
    let priorities: [TransactionPriority] = [TransactionPriority.Low, TransactionPriority.Medium, TransactionPriority.High, TransactionPriority.Custom]

    @IBOutlet weak var unitTextField: UITextField!
    @IBOutlet weak var unitLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        unitTextField.delegate = self
        updateUnitUI()
        hideKeyboardWhenTappedAround()
    }

    func updateUnitUI() {
        if(SettingsStore.shared.getFeeSettings().0 == TransactionPriority.Custom) {
            unitLabel.isHidden = false
            unitTextField.isHidden = false
            unitTextField.text = String(SettingsStore.shared.getFeeSettings().1)
        } else {
            unitLabel.isHidden = true
            unitTextField.isHidden = true
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if let satoshi = Int(textField.text!) {
            SettingsStore.shared.setFeeSettings(satoshi: satoshi, priority: TransactionPriority.Custom)
        }
        updateUnitUI()
        tableView.reloadData()
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return 45
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return priorities.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CurrencyCell", for: indexPath) as! DenominationCell
        let priority = priorities[indexPath.row].rawValue
        cell.leftLabel.text = priority
        if (priority == SettingsStore.shared.getFeeSettings().0.rawValue) {
            cell.rightImageView.isHidden = false
        } else {
            cell.rightImageView.isHidden = true
        }
        cell.selectionStyle = .none
        cell.separatorInset = UIEdgeInsetsMake(0, 16, 0, 16)
        return cell;
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let priority = priorities[indexPath.row]
        if(priority == TransactionPriority.Custom) {
            unitLabel.isHidden = false
            unitTextField.isHidden = false
            unitTextField.becomeFirstResponder()
        } else {
            SettingsStore.shared.setFeeSettings(satoshi: 0, priority: priority)
            updateUnitUI()
            tableView.reloadData()
        }
    }
}
