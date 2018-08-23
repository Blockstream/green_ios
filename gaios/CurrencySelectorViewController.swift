//
//  CurrencySelectorViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 8/22/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class CurrencySelectorViewController : UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    var currencyList: Array<CurrencyItem> = Array<CurrencyItem>()

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        getAvailableCurrencies()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return 45
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currencyList.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CurrencyCell", for: indexPath) as! CurrencyCell
        let currency = currencyList[indexPath.row]
        cell.source.text = currency.exchange
        cell.fiat.text = currency.currency
        cell.selectionStyle = .none
        cell.separatorInset = UIEdgeInsetsMake(0, 16, 0, 16)
        return cell;
    }

    func reloadData() {
        tableView.reloadData()
    }

    func getAvailableCurrencies() {
        wrap{ try getSession().getAvailableCurrencies()}.done{(json: [String:Any]?) in
            print("succesfully received currencies")
            if (json == nil) {
                return
            }
            let perExchange = json?["per_exchange"] as! [String:Any]
            for (exchange, array) in perExchange {
                let currencies = array as! NSArray
                for currency in currencies {
                    let item = CurrencyItem(exchange: exchange, currency: currency as! String)
                    self.currencyList.append(item)
                    print(currency)
                }
            }
            self.reloadData()
            }.catch { error in
                print("couldn't get currencies")
        }
    }

}

class CurrencyItem: Codable{
    var exchange: String
    var currency: String

    init(exchange: String, currency: String) {
        self.currency = currency
        self.exchange = exchange
    }
}


