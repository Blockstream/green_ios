import UIKit
import core
import gdk

protocol AssetExpandableSelectViewControllerDelegate: AnyObject {
    func didSelectReceiver(assetId: String, account: WalletItem)
}

class AssetExpandableSelectViewController: KeyboardViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchCard: UIView!
    @IBOutlet weak var btnSearch: UIButton!
    @IBOutlet weak var searchField: UITextField!

    private var headerH: CGFloat = 54.0
    private var footerH: CGFloat = 54.0
    private var prevTag: Int = 0

    var viewModel: AssetExpandableSelectViewModel!
    weak var delegate: AssetExpandableSelectViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        ["AccountSelectSubCell" ].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
        searchField.delegate = self
        setContent()
        setStyle()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    func setContent() {
        title = "id_select_asset".localized
        searchField.attributedPlaceholder = NSAttributedString(string: "id_search_asset".localized, attributes: [NSAttributedString.Key.foregroundColor: UIColor.white.withAlphaComponent(0.4)])
    }

    func setStyle() {
        searchCard.cornerRadius = 5.0
    }

    @objc func triggerTextChange() {
        viewModel.selected = .none
        viewModel.search(searchField.text ?? "")
        tableView.reloadData()
    }

    func onCreate(section: AssetExpandableSection) {
        AnalyticsManager.shared.newAccount(account: AccountsRepository.shared.current)
        let storyboard = UIStoryboard(name: "Utility", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SecuritySelectViewController") as? SecuritySelectViewController {
            switch section {
            case .anyLiquid:
                vc.viewModel = SecuritySelectViewModel(anyLiquidAsset: true)
            case .anyAmp:
                vc.viewModel = SecuritySelectViewModel(anyLiquidAmpAsset: true)
            case .asset(let assetId):
                vc.viewModel = SecuritySelectViewModel(asset: assetId)
            case .none:
                vc.viewModel = SecuritySelectViewModel(asset: GdkNetworks.liquidSS.policyAsset ?? AssetInfo.btcId)
            }
            vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    @IBAction func onEditingChange(_ sender: Any) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.triggerTextChange), object: nil)
        perform(#selector(self.triggerTextChange), with: nil, afterDelay: 0.5)
    }
}

extension AssetExpandableSelectViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.assetSelectCellModelsFilter.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if viewModel.selected == .none {
            return 0
        } else if viewModel.getSection(index: section) != viewModel.selected {
            return 0
        }
        return viewModel.accountSelectSubCellModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if let cell = tableView.dequeueReusableCell(withIdentifier: AccountSelectSubCell.identifier, for: indexPath) as? AccountSelectSubCell {
           cell.configure(model: viewModel.accountSelectSubCellModels[indexPath.row], isLast: viewModel.accountSelectSubCellModels.count - 1 == indexPath.row)
            cell.selectionStyle = .none
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if viewModel.getSection(index: section) != viewModel.selected {
            return 0.1
        }
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let section = viewModel.getSection(index: section)
        if section != viewModel.selected { return nil }
        let enableCreate = !(WalletManager.current?.isWatchonly ?? false)
        if let createView = Bundle.main.loadNibNamed("AccountCreateFooterView", owner: self, options: nil)?.first as? AccountCreateFooterView {
            createView.configure(
                enableCreate: enableCreate,
                hasAccounts: viewModel.accountSelectSubCellModels.count > 0,
                onTap: { [weak self] in self?.onCreate(section: section) })
            return createView
        }
        return nil
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let accountView = Bundle.main.loadNibNamed("AssetExpandableView", owner: self, options: nil)?.first as? AssetExpandableView {
            let cellModel = viewModel.assetSelectCellModelsFilter[section]
            let currentSection = viewModel.getSection(index: section)
            accountView.configure(model: cellModel,
                                  hasAccounts: viewModel.accountSelectSubCellModels.count > 0,
                                  open: viewModel.selected == currentSection)

            let handler = UIButton(frame: accountView.tapView.frame)
            handler.tag = section
            handler.borderColor = .red
            handler.addTarget(self, action: #selector(didSelectSection(sender:)), for: .touchUpInside)
            accountView.addSubview(handler)
            return accountView
        }
        return nil
    }

    @objc
    private func didSelectSection(sender: UIButton) {
        dismissKeyboard()
        let section = viewModel.getSection(index: sender.tag)
        let tapSelected = viewModel.selected == section
        // close previous section
        if viewModel.selected != .none {
            viewModel.selected = .none
            viewModel.loadAccounts(viewModel.selected)
            tableView.reloadSections(IndexSet([prevTag]), with: .fade)
        }
        // open section if user tap on another
        if !tapSelected {
            prevTag = sender.tag
            viewModel.selected = section
            viewModel.loadAccounts(viewModel.selected)
            tableView.reloadSections(IndexSet([sender.tag]), with: .fade)
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
            if self.viewModel.accountSelectSubCellModels.count > 0 && self.viewModel.selected != .none {
                self.tableView?.scrollToRow(at: IndexPath(row: 0, section: sender.tag), at: .middle, animated: true)
            }
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var assetId = AssetInfo.lbtcId
        switch viewModel.getSection(index: indexPath.section) {
        case .asset(let id):
            assetId = id
        default:
            break
        }
        let account = viewModel.accountSelectSubCellModels[indexPath.row].account
        AnalyticsManager.shared.selectAccount(account: AccountsRepository.shared.current, walletItem: account)
        AnalyticsManager.shared.selectAsset(account: AccountsRepository.shared.current)
        delegate?.didSelectReceiver(assetId: assetId, account: account)
        navigationController?.popViewController(animated: true)
    }
}

extension AssetExpandableSelectViewController {

    func headerView(_ txt: String) -> UIView {

        let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: headerH))
        section.backgroundColor = UIColor.clear
        let title = UILabel(frame: .zero)
        title.font = .systemFont(ofSize: 14.0, weight: .semibold)
        title.text = txt
        title.textColor = .white.withAlphaComponent(0.6)
        title.numberOfLines = 1

        title.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(title)

        NSLayoutConstraint.activate([
            title.centerYAnchor.constraint(equalTo: section.centerYAnchor, constant: 10.0),
            title.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 30),
            title.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: 30)
        ])

        return section
    }
}

extension AssetExpandableSelectViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
}

extension AssetExpandableSelectViewController: SecuritySelectViewControllerDelegate {
    func didCreatedWallet(_ wallet: WalletItem) {

        AnalyticsManager.shared.createAccount(account: AccountsRepository.shared.current, walletItem: wallet)
        delegate?.didSelectReceiver(assetId: getAssetId(), account: wallet)
        navigationController?.popViewController(animated: true)
    }

    func getAssetId() -> String {
        let testnet = AccountsRepository.shared.current?.networkType.testnet ?? false
        switch viewModel.selected {
        case .anyLiquid:
            return testnet ? AssetInfo.ltestId : AssetInfo.lbtcId
        case .anyAmp:
            return testnet ? AssetInfo.ltestId : AssetInfo.lbtcId
        case .asset(let id):
            return id
        case .none:
            return testnet ? AssetInfo.btcId : AssetInfo.testId
        }
    }
}
