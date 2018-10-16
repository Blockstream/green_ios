//
//  TransactionFeeViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 10/16/18.
//  Copyright © 2018 Blockstream.inc All rights reserved.
//

import Foundation
import UIKit

class TransactionFeeViewController : UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    let priorities: [TransactionPriority] = [TransactionPriority.Low, TransactionPriority.Medium, TransactionPriority.High, TransactionPriority.Custom]

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
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
        SettingsStore.shared.setFeeSettings(satoshi: 0, priority: priority)
        tableView.reloadData()
    }
}
