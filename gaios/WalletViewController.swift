//
//  WalletViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 6/20/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class WalletViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    var mainbalance: Double = 0


    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "WalletCard", bundle: nil)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        tableView.register(nib, forCellReuseIdentifier: "walletCard")
        tableView.allowsSelection = false
        tableView.separatorColor = UIColor.clear
        do {
            let json = try getSession().getBalance(numConfs: 1)
            var val:String? = json!["satoshi"] as? String
            let balance: Int? = Int(val!)
            print("balance is ", balance)
            mainbalance = Double(balance!)
        } catch {
        }
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewWillAppear(_ animated: Bool) {
        self.tabBarController?.tabBar.isHidden = false
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return 230.0;
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "walletCard", for: indexPath) as! WalletTableCell
        let balance: Double = Double(mainbalance / 100000000)
        cell.balance.text = String(format: "%g BTC", balance)
        cell.backgroundColor = UIColor.clear
        return cell;

    }

    @objc func send(_ sender: UIButton) {
        self.performSegue(withIdentifier: "sendBtc", sender: self)
    }

    @objc func receive(_ sender: UIButton) {
        self.performSegue(withIdentifier: "receiveBtc", sender: self)
    }
    @objc func addAccount(_ sender: UIButton) {
        let alert = UIAlertController(title: "Name for new wallet", message: "", preferredStyle: .alert)

        alert.addTextField { (textField) in
            textField.placeholder = "Wallet1"
        }

        alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { [weak alert] (_) in
            let textField = alert?.textFields![0] // Force unwrapping because we know it exists.
            print("Text field: \(textField?.text)")
        }))

        self.present(alert, animated: true, completion: nil)
    }
}

