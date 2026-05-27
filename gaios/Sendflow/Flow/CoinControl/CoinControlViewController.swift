import UIKit
import core

class CoinControlViewController: UIViewController {
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var tableViewHeaderLabel: UILabel!
    @IBOutlet weak var sortButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var totalSelectedLabel: UILabel!
    @IBOutlet weak var totalAmountLabel: UILabel!
    @IBOutlet weak var totalAmountFiatLabel: UILabel!
    @IBOutlet weak var confirmButton: UIButton!
    @IBOutlet weak var scrollShadowView: UIView!
    @IBOutlet weak var totalDividerView: UIView!
    @IBOutlet weak var selectButton: UIButton!

    let viewModel: CoinControlViewModel
    weak var delegate: CoinControlDelegate?

    init?(coder: NSCoder, viewModel: CoinControlViewModel) {
        self.viewModel = viewModel
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }

    lazy var emptyFilteredStateView: UIView = {
        return makeStateView(
            icon: UIImage(resource: .icFunnelXLight),
            title: "No coins match your filters".localized,
            subtitle: "Try adjusting or resetting your filters.".localized,
            buttonTitle: "Reset filters".localized,
            buttonAction: #selector(didTapResetFilters)
        )
    }()
    
    lazy var errorStateView: UIView = {
        return makeStateView(
            icon: UIImage(resource: .icEmptyLight),
            title: "Error".localized,
            subtitle: "Unable to load coins.\nPlease try again".localized,
            buttonTitle: "Retry".localized,
            buttonAction: #selector(pullTableViewToRefresh)
        )
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Coin Selection".localized
        setTableView()
        setRightNavigationBarItem()
        setContent()
        setStyles()
        loadData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let gradientLayer = scrollShadowView.layer.sublayers?.first(where: { $0 is CAGradientLayer }) {
            gradientLayer.frame = scrollShadowView.bounds
        } else {
            let gradient = CAGradientLayer()
            gradient.frame = scrollShadowView.bounds

            let color: UIColor = .gBlackBg()

            gradient.colors = [
                color.withAlphaComponent(0.0).cgColor,
                color.cgColor
            ]

            gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
            gradient.endPoint = CGPoint(x: 0.5, y: 1.0)
            gradient.locations = [0.0, 1.0]

            scrollShadowView.layer.insertSublayer(gradient, at: 0)
        }
    }

    func setContent() {
        descriptionLabel.text = "Choose which coins to use for the transaction.".localized
        tableViewHeaderLabel.text = "Coins".localized
        sortButton.setTitle(viewModel.selectedSort.title, for: .normal)
        confirmButton.setTitle("Confirm".localized, for: .normal)
        selectButton.setTitle("Select All", for: .normal)

        sortButton.addTarget(self, action: #selector(sortButtonTapped), for: .touchUpInside)
        selectButton.addTarget(self, action: #selector(selectButtonTapped), for: .touchUpInside)
    }
    
    func setStyles() {
        [descriptionLabel, tableViewHeaderLabel].forEach {
            $0?.setStyle(.txtSectionHeader)
        }
        var sortConfig = UIButton.Configuration.plain()
        sortConfig.image = UIImage(resource: .icSortAscendingLight)
        sortConfig.imagePlacement = .trailing
        sortConfig.imagePadding = 8.0
        sortConfig.baseForegroundColor = .gAccent()
        sortConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        sortConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 16.0, weight: .regular)
            return outgoing
        }
        sortButton.configuration = sortConfig

        totalSelectedLabel.setStyle(.txtSectionHeader)
        selectButton.setStyle(.inline)
        selectButton.titleLabel?.font = UIFont.systemFont(ofSize: 16.0, weight: .medium)

        totalAmountLabel.setStyle(.txtSectionHeader)
        totalAmountLabel.textColor = .white
        totalAmountLabel.font = UIFont.systemFont(ofSize: totalAmountLabel.font.pointSize, weight: .semibold)
        totalAmountFiatLabel.setStyle(.txtSectionHeader)

        totalDividerView.backgroundColor = .gGrayCardBorder()

        confirmButton.setStyle(.primary)
    }
    
    func setTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UINib(nibName: CoinCell.identifier, bundle: nil), forCellReuseIdentifier: CoinCell.identifier)

        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl!.tintColor = UIColor.white
        tableView.refreshControl!.addTarget(self, action: #selector(pullTableViewToRefresh(_:)), for: .valueChanged)
    }

    func setRightNavigationBarItem() {
        guard !CoinFilter.filters(for: viewModel.subaccount).isEmpty else { return }
        let button = UIButton(type: .custom)
        button.setImage(UIImage(resource: .icFunnelLight), for: .normal)
        button.addTarget(self, action: #selector(filterButtonTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
    }

    func loadData() {
        if tableView.refreshControl?.isRefreshing == false {
            startAnimating()
        }
        Task {
            do {
                try await viewModel.loadUtxos()
                await MainActor.run {
                    stopAnimating()
                    tableView.reloadData { [weak self] in
                        self?.tableView.refreshControl?.endRefreshing()
                        self?.updateEmptyState()
                        self?.updateFilterButtonBadge()
                        self?.reloadSummary()
                    }
                }
            } catch {
                viewModel.error = error
                await MainActor.run {
                    stopAnimating()
                    tableView.reloadData { [weak self] in
                        self?.tableView.refreshControl?.endRefreshing()
                        self?.updateEmptyState()
                        self?.updateFilterButtonBadge()
                        self?.reloadSummary()
                    }
                }
            }
        }
    }
    
    func reloadSummary() {
        let utxosCount = viewModel.selectedUtxos.count
        let satoshi = viewModel.selectedUtxos.compactMap { $0.satoshi }.reduce(0, +)
        let coinsText = utxosCount == 1 ? "Coin" : "Coins"

        totalAmountFiatLabel.isHidden = utxosCount == 0
        totalSelectedLabel.text = "\(utxosCount) \(coinsText) Selected"
        
        if utxosCount == 0 {
            totalAmountLabel.text = viewModel.filteredUtxos.isEmpty ? "No coins available".localized : "Using all available coins".localized
            totalAmountLabel.font = UIFont.systemFont(ofSize: 14.0, weight: .semibold)
            totalAmountFiatLabel.text = ""
        } else {
            let btcText = Balance.fromSatoshi(satoshi, assetId: viewModel.assetId)?.toText(viewModel.denomination) ?? ""
            let fiatText = Balance.fromSatoshi(satoshi, assetId: viewModel.assetId)?.toFiatText() ?? ""
            totalAmountLabel.text = viewModel.isFiat ? fiatText : btcText
            totalAmountFiatLabel.text = fiatText
            totalAmountLabel.font = UIFont.systemFont(ofSize: 16.0, weight: .semibold)
        }

        updateSelectButton()
    }
    
    func updateFilterButtonBadge() {
        let hasFilters = !viewModel.selectedFilters.isEmpty
        
        guard let filterButton = navigationItem.rightBarButtonItem?.customView as? UIButton else { return }
        if hasFilters {
            filterButton.setImage(UIImage(resource: .icFunnelLight).withBadge(iconColor: .gAccent(), badgeColor: .gAccent(), borderColor: .gBlackBg(), borderWidth: 1.0, badgeOffset: CGPoint(x: 0, y: 1)), for: .normal)
        } else {
            filterButton.setImage(UIImage(resource: .icFunnelLight).withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        }
    }

    func updateSelectButton() {
        if viewModel.filteredUtxos.isEmpty {
            selectButton.setTitle("Select All".localized, for: .normal)
            selectButton.setStyle(.inlineDisabled)
            selectButton.isEnabled = false
        } else {
            let selectedIds = Set(viewModel.selectedUtxos.compactMap { "\($0.txhash ?? ""):\($0.ptIdx ?? 0)" })
            let allSelected = viewModel.filteredUtxos.allSatisfy { selectedIds.contains("\($0.txhash ?? ""):\($0.ptIdx ?? 0)") }
            if allSelected {
                selectButton.setTitle("Unselect All".localized, for: .normal)
            } else {
                selectButton.setTitle("Select All".localized, for: .normal)
            }
            selectButton.setStyle(.inline)
            selectButton.isEnabled = true
        }
    }

    func updateEmptyState() {
        if viewModel.error != nil {
            tableView.backgroundView = errorStateView
        } else if viewModel.filteredUtxos.isEmpty {
            tableView.backgroundView = emptyFilteredStateView
        } else {
            tableView.backgroundView = nil
        }
    }
    
    func presentFilterViewController() {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "CoinFilterViewController") as? CoinFilterViewController {
            vc.delegate = self
            vc.filters = CoinFilter.filters(for: viewModel.subaccount)
            vc.selectedFilters = viewModel.selectedFilters
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    func presentSortViewController() {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "CoinSortViewController") as? CoinSortViewController {
            vc.delegate = self
            vc.selectedSort = viewModel.selectedSort
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    func selectAllCoins() {
        let selectedIds = Set(viewModel.selectedUtxos.compactMap { "\($0.txhash ?? ""):\($0.ptIdx ?? 0)" })
        let allSelected = viewModel.filteredUtxos.allSatisfy { selectedIds.contains("\($0.txhash ?? ""):\($0.ptIdx ?? 0)") }
        
        if allSelected {
            viewModel.unselectAllFiltered()
        } else {
            viewModel.selectAllFiltered()
        }
        
        tableView.reloadData()
        updateFilterButtonBadge()
        reloadSummary()
    }

    private func makeStateView(
        icon: UIImage?,
        title: String,
        subtitle: String,
        buttonTitle: String,
        buttonAction: Selector
    ) -> UIView {
        let container = UIView()

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: icon)
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.setStyle(.txtSectionHeader)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.setStyle(.txtSectionHeader)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        let button = UIButton(type: .custom)
        button.setTitle(buttonTitle, for: .normal)
        button.setStyle(.inline)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        button.addTarget(self, action: buttonAction, for: .touchUpInside)

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.addArrangedSubview(button)
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 64),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -64),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40)
        ])

        return container
    }

    @objc func filterButtonTapped(_ sender: Any) {
        presentFilterViewController()
    }

    @objc func sortButtonTapped(_ sender: Any) {
        presentSortViewController()
    }

    @objc func selectButtonTapped(_ sender: Any) {
        selectAllCoins()
    }

    @objc func pullTableViewToRefresh(_ sender: UIRefreshControl? = nil) {
        loadData()
    }

    @objc func didTapResetFilters() {
        viewModel.selectedFilters.removeAll()
        tableView.reloadData()
        updateEmptyState()
        updateFilterButtonBadge()
        reloadSummary()
    }

    @IBAction func confirmSelectedUtxos(_ sender: Any) {
        delegate?.didSelectCoins(viewModel.selectedUtxos)
        navigationController?.popViewController(animated: true)
    }
}

extension CoinControlViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.filteredUtxos.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: CoinCell.identifier) as? CoinCell {
            let utxo = viewModel.filteredUtxos[indexPath.row]
            let isSelected = viewModel.isSelected(utxo)

            cell.configure(utxo, isSelected: isSelected, denomination: viewModel.denomination, isFiat: viewModel.isFiat)
            cell.onInfoTapped = { [weak self] in
                guard let self = self else { return }
                let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
                if let vc = storyboard.instantiateViewController(withIdentifier: "CoinDetailsViewController") as? CoinDetailsViewController {
                    vc.viewModel = CoinDetailsViewModel(
                        utxo: utxo,
                        account: self.viewModel.subaccount,
                        denomination: self.viewModel.denomination,
                        isFiat: self.viewModel.isFiat
                    )
                    vc.viewModel.onUpdate = { [weak vc] in
                        vc?.tableView.reloadData()
                        vc?.view.layoutIfNeeded()
                    }
                    vc.modalPresentationStyle = .overCurrentContext
                    self.present(vc, animated: false)
                }
            }
            cell.selectionStyle = .none
            
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel.toggleSelection(viewModel.filteredUtxos[indexPath.row])
        tableView.reloadRows(at: [indexPath], with: .automatic)
        updateFilterButtonBadge()
        reloadSummary()
    }
}

extension CoinControlViewController: CoinFilterDelegate {
    func didSelectFilter(filters: Set<CoinFilter>) {
        viewModel.selectedFilters = filters
        tableView.reloadData()
        updateEmptyState()
        updateFilterButtonBadge()
        reloadSummary()
    }
}

extension CoinControlViewController: CoinSortDelegate {
    func didSelectSort(sort: CoinSort) {
        viewModel.selectedSort = sort
        sortButton.setTitle(sort.title, for: .normal)
        tableView.reloadData()
    }
}
