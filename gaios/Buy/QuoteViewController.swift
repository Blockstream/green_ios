import Foundation
import BreezSDK
import UIKit
import LinkPresentation
import gdk
import hw
import Combine
import core

class QuoteViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    var viewModel: BuyViewModel!
    var quotes = [MeldQuoteItem]()

    override func viewDidLoad() {
        super.viewDidLoad()
        setContent()

        Task { [weak self] in
            await self?.reload()
        }
    }

    func setContent() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl!.tintColor = UIColor.white
        tableView.refreshControl!.addTarget(self, action: #selector(pull(_:)), for: .valueChanged)
    }

    @objc func pull(_ sender: UIRefreshControl? = nil) {
        Task { [weak self] in
            await self?.reload()
        }
    }

    func reload() async {
        if !(tableView.refreshControl?.isRefreshing ?? false) {
            tableView.beginRefreshing()
        }
        let task = Task.detached { [weak self] in
            return try await self?.viewModel.quote()
        }
        let res = await task.result
        if tableView.refreshControl?.isRefreshing ?? false {
            tableView.endRefreshing()
        }
        switch res {
        case .success(let quotes):
            self.quotes = quotes ?? []
            self.tableView.reloadData()
        case .failure(let err):
            showError(err.description()?.localized ?? err.localizedDescription)
        }
    }

    func widget(quote: MeldQuoteItem) async {
        startAnimating()
        let task = Task.detached { [weak self] in
            return try await self?.viewModel.widget(quote: quote)
        }
        let res = await task.result
        stopAnimating()
        switch res {
        case .success(let url):
            AnalyticsManager.shared.buyRedirect(account: self.viewModel.wm.account)
            SafeNavigationManager.shared.navigate(url, exitApp: false)
        case .failure(let err):
            showError(err.description()?.localized ?? err.localizedDescription)
        }
    }
}
extension QuoteViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return quotes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let quote = quotes[safe: indexPath.row] else {
            return UITableViewCell()
        }
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "MeldQuoteViewCell")
        cell.textLabel?.text = String(format: "\(quote.serviceProvider) (%.2f)", quote.customerScore)
        cell.detailTextLabel?.text = String(quote.exchangeRate)
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let quote = quotes[safe: indexPath.row] else {
            return
        }
        Task { [weak self] in
            await self?.widget(quote: quote)
        }
    }
}
