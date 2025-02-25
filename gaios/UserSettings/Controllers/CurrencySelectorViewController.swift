import Foundation
import UIKit
import core

class CurrencySelectorViewController: KeyboardViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var textField: SearchTextField!
    @IBOutlet weak var currentCurrency: UILabel!
    @IBOutlet weak var currentExchange: UILabel!

    private var currencyList = [CurrencyItem]()
    private var searchCurrencyList = [CurrencyItem]()
    private var session: SessionManager? { WalletManager.current?.prominentSession }
    weak var delegate: UserSettingsViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "id_reference_exchange_rate".localized
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        tableView.separatorColor = UIColor.customTitaniumMedium()
        textField.delegate = self
        textField.attributedPlaceholder = NSAttributedString(string: "id_search".localized,
                                                   attributes: [NSAttributedString.Key.foregroundColor: UIColor.customTitaniumLight()])
        textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)

        tableView.rowHeight = 50
        tableView.layer.shadowColor = UIColor.white.cgColor
        tableView.layer.shadowRadius = 4
        tableView.layer.shadowOpacity = 1
        tableView.layer.shadowOffset = CGSize(width: 20, height: 50)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        getCurrentRate()
        getExchangeRate()
    }

    func getCurrentRate() {
        if let settings = session?.settings {
            currentCurrency.text = settings.pricing["currency"] ?? ""
            currentExchange.text = settings.pricing["exchange"]?.capitalized ?? ""
        }
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        if textField.text == nil || (textField.text?.isEmpty)! {
            searchCurrencyList = currencyList
            self.tableView.reloadData()
            return
        }
        let filteredStrings = currencyList.filter({(item: CurrencyItem) -> Bool in
            let stringMatch = item.currency.lowercased().range(of: textField.text!.lowercased())
                return stringMatch != nil ? true : false
        })
        searchCurrencyList = filteredStrings
        self.tableView.reloadData()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchCurrencyList.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "CurrencyCell", for: indexPath) as? CurrencyCell else { fatalError("Fail to dequeue reusable cell") }
        let currency = searchCurrencyList[indexPath.row]
        cell.source.text = currency.exchange.capitalized
        cell.fiat.text = currency.currency
        cell.selectionStyle = .none
        cell.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let currency = searchCurrencyList[indexPath.row]
        setExchangeRate(currency)
    }

    func setExchangeRate(_ currency: CurrencyItem) {
        guard let session = session, let settings = session.settings else { return }
        var pricing = [String: String]()
        pricing["currency"] = currency.currency
        pricing["exchange"] = currency.exchange
        Task {
            do {
                settings.pricing = pricing
                try await session.changeSettings(settings: settings)
                self.delegate?.refresh()
                self.navigationController?.popViewController(animated: true)
            } catch {
                self.showError("id_your_favourite_exchange_rate_is".localized)
            }
        }
    }

    func getExchangeRate() {
        guard let session = session else { return }
        Task {
            let perExchange = try? await session.getAvailableCurrencies()
            self.currencyList.removeAll()
            for (exchange, array) in perExchange ?? [:] {
                for currency in array {
                    self.currencyList.append(CurrencyItem(exchange: exchange, currency: currency))
                }
            }
            self.searchCurrencyList = self.currencyList
            self.tableView.reloadData()
        }
    }
}

class CurrencyItem: Codable, Equatable {
    var exchange: String
    var currency: String

    init(exchange: String, currency: String) {
        self.currency = currency
        self.exchange = exchange
    }

    public static func == (lhs: CurrencyItem, rhs: CurrencyItem) -> Bool {
        return lhs.exchange == rhs.exchange &&
            lhs.currency == rhs.currency
    }
}
