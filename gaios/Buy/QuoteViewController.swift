import Foundation
import BreezSDK
import UIKit
import LinkPresentation
import gdk
import hw
import Combine
import core

/// Controller that displays a list of provider quotes and allows users to select one
class QuoteViewController: UIViewController {

    // MARK: - Properties
    
    /// Table view for displaying quote options
    @IBOutlet weak var tableView: UITableView!
    
    /// View model containing buy logic and data
    var viewModel: BuyViewModel!
    
    /// Available quotes from providers
    private var quotes = [MeldQuoteItem]()
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        loadQuotes()
    }
    
    // MARK: - Setup
    
    /// Sets up the user interface
    private func setupUI() {
        configureNavigationBar()
        configureTableView()
    }
    
    /// Configures the navigation bar
    private func configureNavigationBar() {
        title = "Select Provider"
    }
    
    /// Configures the table view and registers cells
    private func configureTableView() {
        // Configure table view delegates
        tableView.delegate = self
        tableView.dataSource = self
        
        // Set up pull to refresh
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = UIColor.white
        refreshControl.addTarget(self, action: #selector(pull(_:)), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        // Register custom cell
        tableView.register(UINib(nibName: "QuoteCell", bundle: nil), forCellReuseIdentifier: "QuoteCell")
        
        // Configure table view appearance
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        
        // Add empty footer to remove extra separators
        tableView.tableFooterView = UIView()
    }
    
    // MARK: - Data Loading
    
    /// Initiates loading quote data
    private func loadQuotes() {
        Task { [weak self] in
            await self?.reload()
        }
    }
    
    /// Refreshes quote data when the user pulls to refresh
    @objc private func pull(_ sender: UIRefreshControl? = nil) {
        Task { [weak self] in
            await self?.reload()
        }
    }
    
    /// Reloads quotes from the API and updates the UI
    private func reload() async {
        showLoadingIndicator()
        
        let task = Task.detached { [weak self] in
            return try await self?.viewModel.quote()
        }
        
        let result = await task.result
        hideLoadingIndicator()
        
        switch result {
        case .success(let quotes):
            processQuotes(quotes)
        case .failure(let error):
            handleError(error)
        }
    }
    
    /// Processes and displays quotes after successful loading
    /// - Parameter quotes: The quotes received from the API
    private func processQuotes(_ quotes: [MeldQuoteItem]?) {
        // Sort quotes by destination amount (highest first)
        self.quotes = (quotes ?? []).sorted(by: { $0.destinationAmount > $1.destinationAmount })
        self.tableView.reloadData()
    }
    
    /// Shows the loading indicator
    private func showLoadingIndicator() {
        if !(tableView.refreshControl?.isRefreshing ?? false) {
            tableView.beginRefreshing()
        }
    }
    
    /// Hides the loading indicator
    private func hideLoadingIndicator() {
        if tableView.refreshControl?.isRefreshing ?? false {
            tableView.endRefreshing()
        }
    }
    
    /// Handles errors during quote loading
    /// - Parameter error: The error that occurred
    private func handleError(_ error: Error) {
        showError(error.description()?.localized ?? error.localizedDescription)
    }
    
    // MARK: - Provider Selection
    
    /// Initiates the widget flow for the selected quote
    /// - Parameter quote: The selected quote
    private func selectProvider(_ quote: MeldQuoteItem) {
        Task { [weak self] in
            await self?.widget(quote: quote)
        }
    }
    
    /// Loads and displays the Meld widget for the selected quote
    /// - Parameter quote: The selected quote
    private func widget(quote: MeldQuoteItem) async {
        startAnimating()
        
        let task = Task.detached { [weak self] in
            return try await self?.viewModel.widget(quote: quote)
        }
        
        let result = await task.result
        stopAnimating()
        
        switch result {
        case .success(let url):
            proceedWithWidget(url: url)
        case .failure(let error):
            handleError(error)
        }
    }
    
    /// Proceeds with the widget URL after successful loading
    /// - Parameter url: The widget URL to navigate to
    private func proceedWithWidget(url: String?) {
        AnalyticsManager.shared.buyRedirect(account: self.viewModel.wm.account)
        SafeNavigationManager.shared.navigate(url, exitApp: false)
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource

extension QuoteViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return quotes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let quote = quotes[safe: indexPath.row],
              let cell = tableView.dequeueReusableCell(withIdentifier: "QuoteCell", for: indexPath) as? QuoteCell else {
            return UITableViewCell()
        }
        
        // Determine if this is the best quote (first row after sorting)
        let isBestQuote = indexPath.row == 0
        
        // Configure the cell with the quote data
        cell.configure(with: quote, amount: quote.destinationAmount, isBestQuote: isBestQuote)
        
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 95 // Same as the height defined in the XIB
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let quote = quotes[safe: indexPath.row] else {
            return
        }
        
        // Add a subtle animation to show the cell was selected
        if let cell = tableView.cellForRow(at: indexPath) as? QuoteCell {
            animateCellSelection(cell)
        }
        
        selectProvider(quote)
    }
    
    /// Animates the cell selection with a subtle fade effect
    /// - Parameter cell: The cell to animate
    private func animateCellSelection(_ cell: QuoteCell) {
        UIView.animate(withDuration: 0.1, animations: {
            cell.containerView.alpha = 0.7
        }, completion: { _ in
            UIView.animate(withDuration: 0.1) {
                cell.containerView.alpha = 1.0
            }
        })
    }
}
