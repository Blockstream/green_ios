//
//  SettingsViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/18/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    
    let settings:[String] = ["Currency", "Notifications", "nLockTime", "Two Factor Authentication", "Security", "Remove Account"]
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
       return  settings.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "settingsCell", for: indexPath) as! SettingsCell
        cell.label.text = settings[indexPath.row]
        return cell
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
    }
}
