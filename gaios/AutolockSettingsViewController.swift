//
//  AutolockSettingsViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 10/16/18.
//  Copyright © 2018 Blockstream.inc All rights reserved.
//

import Foundation
import Foundation
import UIKit

class AutolockSettingsViewController : UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {


    @IBOutlet weak var tableView: UITableView!
    let autolockTypes: [AutoLock] = [AutoLock.minute, AutoLock.twoMinutes, AutoLock.fiveMinutes, AutoLock.tenMinutes, AutoLock.Custom]

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
            SettingsStore.shared.setAutolockSettings(time: time, type: AutoLock.Custom)
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
            updateUnitUI()
            tableView.reloadData()
        }
    }
}
