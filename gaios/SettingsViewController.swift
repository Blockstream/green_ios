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
    
    let settingTitles:[String] = ["Account", "Security", "Advanced", "About"]
    let sectionAccount:[String] = ["Alternative currency", "Show Bitcoin in", "Watch-only Login"]
    let sectionSecurity:[String] = ["Show Recovery Seed", "Screen Lock", "Two-factor Authentication", "Support"]
    let sectionAdvanced:[String] = ["Enable Segwit", "nLockTimeTransactions", "SPV Synchronization"]
    let sectionAbout:[String] = ["Version", "Terms of use", "Privacy Policy"]
    let settingsIcon:[UIImage] = [#imageLiteral(resourceName: "account"),#imageLiteral(resourceName: "security"),#imageLiteral(resourceName: "advanced"),#imageLiteral(resourceName: "about")]
    var pager: MainMenuPageViewController? = nil

    lazy var allSettings:[[String]] = [sectionAccount, sectionSecurity, sectionAdvanced, sectionAbout]

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let settingsGroup = allSettings[section]
        return  settingsGroup.count
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return  allSettings.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "settingsCell", for: indexPath) as! SettingsCell
        let settingsGroup = allSettings[indexPath.section]
        cell.label.text = settingsGroup[indexPath.row]
        if (indexPath.row == 0 && indexPath.section == 0) {
            cell.rightLabel.text = SettingsStore.shared.getCurrencyString()!
        } else {
            cell.rightLabel.text = ""
        }
        cell.selectionStyle = .none
        cell.separatorInset = UIEdgeInsetsMake(0, 16, 0, 10)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 45
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if(indexPath.section == 0) {
            if (indexPath.row == 0) {
                pager?.hideButtons()
                self.performSegue(withIdentifier: "currency", sender: nil)
            }
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = UIColor.customTitaniumDark()
        let imageView = UIImageView()
        imageView.frame = CGRect(x: 0, y: 0, width: 21, height: 21)
        imageView.image = settingsIcon[section]
        header.insertSubview(imageView, at: 0)
        let title = UILabel()
        title.text = settingTitles[section]
        title.frame = CGRect(x: 0, y: 0, width: 21, height: 41)
        title.translatesAutoresizingMaskIntoConstraints = false
        title.textColor = UIColor.customTitaniumLight()
        header.insertSubview(title, at: 1)
        //constrain <-16[image]->16 [Title]
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        NSLayoutConstraint(item: imageView, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 21).isActive = true
        NSLayoutConstraint(item: imageView, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1, constant: 21).isActive = true
        NSLayoutConstraint(item: imageView, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: header, attribute: NSLayoutAttribute.leading, multiplier: 1, constant: 16).isActive = true
        NSLayoutConstraint(item: imageView, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: header, attribute: NSLayoutAttribute.centerY, multiplier: 1, constant: 0).isActive = true

        NSLayoutConstraint(item: title, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: header, attribute: NSLayoutAttribute.centerY, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: title, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: imageView, attribute: NSLayoutAttribute.trailing, multiplier: 1, constant: 5).isActive = true

        return header
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        pager?.showButtons()
    }
}
