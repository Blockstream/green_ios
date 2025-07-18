import UIKit
import core
import gdk
enum AccountArchiveSection: Int, CaseIterable {
    case account = 0
}
protocol AccountArchiveViewControllerDelegate: AnyObject {
    func archiveDidChange()
}
class AccountArchiveViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    var headerH: CGFloat = 44.0
    var footerH: CGFloat = 54.0
    weak var delegate: AccountArchiveViewControllerDelegate?
    var viewModel = AccountArchiveViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Archived Accounts".localized
        register()
        setContent()
        AnalyticsManager.shared.recordView(.archivedAccounts, sgmt: AnalyticsManager.shared.sessSgmt(AccountsRepository.shared.current))
        loadNavigationBtns()
    }
    func register() {
        ["AccountArchiveCell"].forEach {
            tableView?.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
    }
    @MainActor
    func reloadSections(_ sections: [AccountArchiveSection], animated: Bool) {
        if animated {
            tableView.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
        } else {
            UIView.performWithoutAnimation {
                tableView.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
            }
        }
    }
    func setContent() {
        Task {
            try? await viewModel.loadSubaccounts()
            reloadSections([.account], animated: false)
        }
    }
    func loadNavigationBtns() {
        let settingsBtn = UIButton(type: .system)
        settingsBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14.0, weight: .semibold)
        settingsBtn.setTitle("Unarchive".localized, for: .normal)
        settingsBtn.addTarget(self, action: #selector(unarchive), for: .touchUpInside)
        if viewModel.list.count == 0 {
            settingsBtn.tintColor = UIColor.gGrayTxt()
            settingsBtn.isEnabled = false
        } else {
            settingsBtn.tintColor = UIColor.gAccent()
            settingsBtn.isEnabled = true
        }
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: settingsBtn)
    }
    @objc func unarchive() {
        Task {
            for item in viewModel.list {
                try? await viewModel.unarchiveSubaccount(item)
            }
            await MainActor.run {
                viewModel.list = []
                tableView.reloadData()
                self.delegate?.archiveDidChange()
            }
        }
    }
    func updateList(_ item: WalletItem) {
        if viewModel.list.contains(item) {
            viewModel.list.remove(at: viewModel.list.firstIndex(of: item)!)
        } else {
            viewModel.list.append(item)
        }
        tableView.reloadData()
        loadNavigationBtns()
    }
}

extension AccountArchiveViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return AccountArchiveSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case AccountArchiveSection.account.rawValue:
            return viewModel.accountCellModels.count
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        switch indexPath.section {
        case AccountArchiveSection.account.rawValue:
            let account = viewModel.accountCellModels[indexPath.row].account
            if let cell = tableView.dequeueReusableCell(withIdentifier: "AccountArchiveCell") as? AccountArchiveCell {
                cell.configure(model: viewModel.accountCellModels[indexPath.row],
                               hideBalance: viewModel.hideBalance,
                               isSelected: viewModel.list.contains(account),
                               onTap: {[weak self] in
                    self?.updateList(account)
                })
                cell.selectionStyle = .none
                return cell
            }
        default:
            break
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.1
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch AccountArchiveSection(rawValue: section) {
        case .account:
            if viewModel.accountCellModels.count == 0 {
                return footerH
            } else {
                return 0.1
            }
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        switch AccountArchiveSection(rawValue: section) {
        case .account:
            if viewModel.accountCellModels.count == 0 {
                return sectionFooter("You don't have any archived account.".localized)
            }
            return nil
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) { }
}
extension AccountArchiveViewController {
    func sectionFooter(_ txt: String) -> UIView {

        guard let tView = tableView else { return UIView(frame: .zero) }
        let section = UIView(frame: CGRect(x: 0, y: 0, width: tView.frame.width, height: footerH))
        section.backgroundColor = UIColor.clear
        let title = UILabel(frame: .zero)
        title.setStyle(.txtCard)
        title.text = txt
        title.textColor = UIColor.gGrayTxt()
        title.numberOfLines = 0
        title.textAlignment = .center

        title.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(title)

        NSLayoutConstraint.activate([
            title.centerYAnchor.constraint(equalTo: section.centerYAnchor, constant: 0.0),
            title.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 25),
            title.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -25)
        ])

        return section
    }
}
