import Foundation
import Foundation
import UIKit

class AutolockSettingsViewController : KeyboardViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {


    @IBOutlet weak var tableView: UITableView!
    let autolockTypes: [AutoLock] = [AutoLock.minute, AutoLock.twoMinutes, AutoLock.fiveMinutes, AutoLock.tenMinutes, AutoLock.Custom]
    @IBOutlet weak var warningLabel: UILabel!
    @IBOutlet weak var unitTextField: UITextField!
    @IBOutlet weak var unitLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        unitTextField.delegate = self
        updateUnitUI()
        warningLabel.isHidden = true
        title = NSLocalizedString("id_autolock_after", comment: "")
        unitLabel.text = NSLocalizedString("id_seconds", comment: "")
        warningLabel.text = NSLocalizedString("id_5_seconds_minimum", comment: "")
    }

    func updateUnitUI() {
        if(SettingsStore.shared.getAutolockSettings().0 == AutoLock.Custom) {
            unitLabel.isHidden = false
            unitTextField.isHidden = false
            unitTextField.text = String(SettingsStore.shared.getAutolockSettings().1)
        } else {
            unitLabel.isHidden = true
            unitTextField.isHidden = true
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if let time = Int(textField.text!) {
            if (time < 5) {
                warningLabel.isHidden = false
                return
            } else {
                warningLabel.isHidden = true
                SettingsStore.shared.setAutolockSettings(time: time, type: AutoLock.Custom)
            }
        }
        updateUnitUI()
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return 45
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return autolockTypes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CurrencyCell", for: indexPath) as! DenominationCell
        let lock = autolockTypes[indexPath.row].rawValue
        cell.leftLabel.text = lock
        if (autolockTypes[indexPath.row] == SettingsStore.shared.getAutolockSettings().0) {
            cell.rightImageView.isHidden = false
        } else {
            cell.rightImageView.isHidden = true
        }
        cell.selectionStyle = .none
        cell.separatorInset = UIEdgeInsetsMake(0, 16, 0, 16)
        return cell;
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let lock = autolockTypes[indexPath.row]
        if(lock == AutoLock.Custom) {
            unitLabel.isHidden = false
            unitTextField.isHidden = false
            unitTextField.becomeFirstResponder()
        } else {
            SettingsStore.shared.setAutolockSettings(time: 0, type: lock)
            warningLabel.isHidden = true
            updateUnitUI()
            tableView.reloadData()
        }
    }
}
