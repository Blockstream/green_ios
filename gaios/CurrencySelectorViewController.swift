//
//  CurrencySelectorViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 8/22/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class CurrencySelectorViewController : UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {

    @IBOutlet weak var tableView: UITableView!
    var currencyList: Array<CurrencyItem> = Array<CurrencyItem>()
    var searchCurrencyList: Array<CurrencyItem> = Array<CurrencyItem>()
    @IBOutlet weak var textField: SearchTextField!
    @IBOutlet weak var currentCurrency: UILabel!
    @IBOutlet weak var currentExchange: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        getAvailableCurrencies()
        hideKeyboardWhenTappedAround()
        textField.delegate = self
        textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        refreshCurrency()
    }

    func refreshCurrency() {
        let currencySettings = SettingsStore.shared.getCurrencySettings()
        currentCurrency.text = currencySettings?.settingsProperty["currency"]
        currentExchange.text = currencySettings?.settingsProperty["exchange"]
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        guard let text = textField.text else {
            searchCurrencyList = currencyList
            reloadData()
            return
        }
        if(text == "") {
            searchCurrencyList = currencyList
            reloadData()
        } else {
            let filteredStrings = currencyList.filter({(item: CurrencyItem) -> Bool in
                let stringMatch = item.currency.lowercased().range(of: text.lowercased())
                return stringMatch != nil ? true : false
            })
            searchCurrencyList = filteredStrings
            reloadData()
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return 45
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchCurrencyList.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CurrencyCell", for: indexPath) as! CurrencyCell
        let currency = searchCurrencyList[indexPath.row]
        cell.source.text = currency.exchange
        cell.fiat.text = currency.currency
        cell.selectionStyle = .none
        cell.separatorInset = UIEdgeInsetsMake(0, 16, 0, 16)
        return cell;
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let currency = searchCurrencyList[indexPath.row]
        SettingsStore.shared.setCurrency(currency: currency.currency, exchange: currency.exchange).done {
             self.refreshCurrency()
        }
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
                    self.searchCurrencyList.append(item)
                    print(currency)
                }
            }
            self.reloadData()
            }.catch { error in
                print("couldn't get currencies")
        }
    }
    @IBAction func backButtonPressed(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
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


