//
//  EnterMnemonicsViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/15/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class EnterMnemonicsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource  {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var doneButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "EnterMnemonicsCell", bundle: nil)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        tableView.register(nib, forCellReuseIdentifier: "EnterMnemonicsCell")
        tableView.allowsSelection = false
        tableView.separatorColor = UIColor.clear
        self.navigationController?.setNavigationBarHidden(false, animated: false)

        //edit
    }
    
    @IBAction func doneButtonClicked(_ sender: Any) {
       //let _ = mnemonicWords.joined(separator: " ")
        let trimmedUserProvidedMnemonic = getNetwork() == Network.LocalTest ? "cotton slot artwork now grace assume syrup route moment crisp cargo sock wrap duty craft joy adult typical nut mad way autumn comic silent".trimmingCharacters(in: .whitespacesAndNewlines) : "ignore roast anger enrich income beef snap busy final dutch banner lobster bird unhappy naive spike pond industry time hero trim verb mammal asthma".trimmingCharacters(in: .whitespacesAndNewlines)
        retry(session: getSession(), network: getNetwork()) {
            wrap { return try getSession().login(mnemonic: trimmedUserProvidedMnemonic) }
            }.done { (loginData: [String: Any]?) in
                getGAService().loginData = loginData
                AccountStore.shared.initializeAccountStore()
                self.performSegue(withIdentifier: "mainMenu", sender: self)
            }.catch { error in
                print("Login failed")
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return 45.0;
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 12
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "EnterMnemonicsCell", for: indexPath) as! EnterMnemonicsCell
        cell.leftLabel.text = String(format: "%d", 2*indexPath.row + 1)
        cell.rightLabel.text = String(format: "%d", 2*indexPath.row + 2)
        return cell;
        
    }
    
}
