//
//  TransactionViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/2/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit
import PromiseKit


class TransactionViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    var items = [TransactionItem]()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.reloadData()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "TransactionCell", bundle: nil)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        tableView.register(nib, forCellReuseIdentifier: "transactionCell")
        tableView.allowsSelection = false
        tableView.separatorColor = UIColor.clear
        updateViewModel()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return 65.0;
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "transactionCell", for: indexPath) as! TransactionTableCell
        let item: TransactionItem = items.reversed()[indexPath.row]
        cell.address.text = item.address
        cell.amount.text = item.amount
        cell.month.text = item.month
        cell.day.text = item.day
        return cell;
        
    }
    
    func getTransactions() -> Promise<[Transaction]?> {
        return retry(session: getSession(), network: Network.TestNet) {
            return wrap { return try getSession().getTransactions(subaccount: 0) }
        }
    }
    
    func dateFromTimestamp(date: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.date(from: date)!
    }
    
    
    func updateViewModel() {
        getTransactions().done { (txs: [Transaction]?) in
            self.items.removeAll(keepingCapacity: true)
            for tx in txs ?? [] {
                let json = try! tx.toJSON()!
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .short
                let date = self.dateFromTimestamp(date: json["timestamp"] as! String)
                let dateString = dateFormatter.string(from: date)
                dateFormatter.dateFormat = "LLL"
                let nameOfMonth = dateFormatter.string(from: date)
                dateFormatter.dateFormat = "dd"
                let nameOfDay = dateFormatter.string(from: date)
                let val:String? = json["value_str"] as? String
                let balance: Double? = Double(val!)
                let toBtc: Double = balance! / 100000000
                let formattedBalance: String = String(format: "%g BTC", toBtc)
                let counterparty: String = json["counterparty"] as! String
                self.items.append(TransactionItem(timestamp: dateString, address: counterparty, amount: formattedBalance, fiatAmount: "", month: nameOfMonth, day: nameOfDay))
            }
            }.ensure {
                self.tableView.reloadData()
            }.catch { _ in }
    }
}

class TransactionItem {
    var timestamp: String
    var address: String
    var amount: String
    var fiatAmount: String
    var month: String
    var day: String

    init(timestamp: String, address: String, amount: String, fiatAmount: String, month: String, day: String) {
        self.timestamp = timestamp
        self.address = address
        self.amount = amount
        self.fiatAmount = fiatAmount
        self.day = day
        self.month = month
    }
}
