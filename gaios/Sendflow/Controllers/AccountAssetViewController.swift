import UIKit
import gdk
import core

enum AccountAssetSection: Int, CaseIterable {
    case accountAsset
    case footer
}

protocol AccountAssetViewControllerDelegate: AnyObject {
    func didSelectAccountAsset(account: WalletItem, asset: AssetInfo)
}

class AccountAssetViewController: UIViewController {

    enum FooterType {
        case none
    }

    @IBOutlet weak var tableView: UITableView!

    private var headerH: CGFloat = 54.0
    private var footerH: CGFloat = 54.0

    var viewModel: AccountAssetViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()

        ["AccountAssetCell" ].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }

        navigationItem.backBarButtonItem = UIBarButtonItem(
            title: "id_back".localized, style: .plain, target: nil, action: nil)

        setContent()
        setStyle()

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    func setContent() {
        title = "id_account__asset".localized
    }

    func setStyle() {
    }
}

extension AccountAssetViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return AccountAssetSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        switch AccountAssetSection(rawValue: section) {
        case .accountAsset:
            return viewModel?.accountAssetCellModels.count ?? 0
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        switch AccountAssetSection(rawValue: indexPath.section) {
        case .accountAsset:
            if let cell = tableView.dequeueReusableCell(withIdentifier: AccountAssetCell.identifier, for: indexPath) as? AccountAssetCell,
               let model = viewModel {
                cell.configure(model: model.accountAssetCellModels[indexPath.row])
                cell.selectionStyle = .none
                return cell
            }
        default:
            break
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch AccountAssetSection(rawValue: section) {
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch AccountAssetSection(rawValue: section) {
        case .footer:
            return 100.0
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {

        switch AccountAssetSection(rawValue: indexPath.section) {
        default:
            return UITableView.automaticDimension
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {

        switch AccountAssetSection(rawValue: section) {
        case .accountAsset:
            return nil // headerView( "Accounts" )
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        switch AccountAssetSection(rawValue: section) {
        default:
            return footerView(.none)
        }
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch AccountAssetSection(rawValue: indexPath.section) {
        default:
            return indexPath
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        switch AccountAssetSection(rawValue: indexPath.section) {
        case .accountAsset:
            guard let cellModel = viewModel?.accountAssetCellModels[indexPath.row] else { return }
            viewModel?.select(cell: cellModel)
            sendAmountViewController()
        default:
            break
        }
    }

    func sendAmountViewController() {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendAmountViewController") as? SendAmountViewController {
            vc.viewModel = SendAmountViewModel(createTx: viewModel.createTx!)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension AccountAssetViewController {

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

    func footerView(_ type: FooterType) -> UIView {

        switch type {
        default:
            let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 1.0))
            section.backgroundColor = .clear
            return section
        }
    }
}
