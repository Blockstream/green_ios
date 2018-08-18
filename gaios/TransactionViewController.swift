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
    var items = [NotificationItem]()
    @IBOutlet weak var headerView: UIView!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateViewModel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "NotificationTableCell", bundle: nil)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        tableView.register(nib, forCellReuseIdentifier: "NotificationCell")
        tableView.allowsSelection = false
        tableView.separatorColor = UIColor.customLightGray()
        tableView.tableHeaderView = headerView
        updateViewModel()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        let item = items[indexPath.row]
        let widthContraint = self.tableView.frame.size.width - 84
        let height = item.text.heightWithConstrainedWidth(width: widthContraint, font: UIFont.systemFont(ofSize: 12, weight: .light))
        //let size = item.text
        let total = 88 + height + 40
        return total
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationCell", for: indexPath) as! NotificationTableCell
        let item: NotificationItem = items.reversed()[indexPath.row]
        cell.mainText.text = item.text
        cell.title.text = item.title
        cell.date.text = item.date
        cell.date.sizeToFit()
        cell.title.sizeToFit()
        cell.separatorInset = UIEdgeInsetsMake(0, 42, 0, 16)
        return cell;
        
    }

    func updateViewModel() {
        items = NotificationStore.shared.getNotifications()
        tableView.reloadData()
    }
}

class TransactionItem: Codable {
    var timestamp: String
    var address: String
    var amount: String
    var fiatAmount: String
    var date: String
    var btc_amount: Double

    init(timestamp: String, address: String, amount: String, fiatAmount: String, date: String, btc: Double) {
        self.timestamp = timestamp
        self.address = address
        self.amount = amount
        self.fiatAmount = fiatAmount
        self.date = date
        self.btc_amount = btc
    }
}
