import Foundation
import UIKit
import core

protocol DrawerNetworkSelectionDelegate: AnyObject {
    func didSelectAccount(account: Account)
    func didSelectAddWallet()
    func didSelectSettings()
    func didSelectAbout()
}

class DrawerNetworkSelectionViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var btnAbout: UIButton!
    @IBOutlet weak var btnSettings: UIButton!
    @IBOutlet weak var newWalletView: UIView!
    @IBOutlet weak var lblNewWallet: UILabel!
    @IBOutlet weak var lblWallets: UILabel!

    var onSelection: ((Account) -> Void)?
    weak var delegate: DrawerNetworkSelectionDelegate?

    var headerH: CGFloat = 44.0
    var footerH: CGFloat = 54.0
    var isAnimating = false

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        tableView.register(UINib(nibName: "WalletListCell", bundle: nil), forCellReuseIdentifier: "WalletListCell")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateShortcut()
    }

    func setContent() {
        lblNewWallet.text = "id_set_up_a_new_wallet".localized
        lblWallets.text = "id_my_wallets".localized
    }

    func setStyle() {
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        view.backgroundColor = UIColor.gBlackBg()
        tableView.backgroundColor = UIColor.gBlackBg()
        newWalletView.setStyle(CardStyle.defaultStyle)
        lblWallets.textColor = UIColor.gGrayTxt()
    }

    func getAccountFromTableView(_ indexPath: IndexPath) -> Account? {
        switch HomeSection(rawValue: indexPath.section) {
        case .swWallet:
            return AccountsRepository.shared.swAccounts[indexPath.row]
        case .ephWallet:
            return AccountsRepository.shared.ephAccounts[indexPath.row]
        case .hwWallet:
            return AccountsRepository.shared.hwVisibleAccounts[indexPath.row]
        default:
            return nil
        }
    }

    func onTap(_ indexPath: IndexPath) {
        onTapOverview(indexPath)
    }

    func onTapOverview(_ indexPath: IndexPath) {
        if let account = getAccountFromTableView(indexPath) {
            self.delegate?.didSelectAccount(account: account)
        }
    }

    @IBAction func btnAddWallet(_ sender: Any) {
        newWalletView.pressAnimate {
            self.delegate?.didSelectAddWallet()
        }
    }

    @IBAction func btnSettings(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {
            vc.delegate = self
            vc.viewModel = DialogListViewModel(title: "Options".localized, type: .walletListPrefs, items: WalletListPrefs.getItems())
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @IBAction func btnClose(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

extension DrawerNetworkSelectionViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return HomeSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch HomeSection(rawValue: section) {
        case .swWallet:
            return AccountsRepository.shared.swAccounts.count
        case .ephWallet:
            return AccountsRepository.shared.ephAccounts.count
        case .hwWallet:
            return AccountsRepository.shared.hwVisibleAccounts.count
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch HomeSection(rawValue: indexPath.section) {
        case .swWallet:
            let account = AccountsRepository.shared.swAccounts[indexPath.row]
            if let cell = tableView.dequeueReusableCell(withIdentifier: "WalletListCell") as? WalletListCell {
                cell.configure(item: account,
                               indexPath: indexPath,
                               onTap: { [weak self] indexPath in self?.onTap(indexPath) }
                )
                cell.selectionStyle = .none
                return cell
            }
        case .ephWallet:
            let account = AccountsRepository.shared.ephAccounts[indexPath.row]
            if let cell = tableView.dequeueReusableCell(withIdentifier: "WalletListCell") as? WalletListCell {
                cell.configure(item: account,
                               indexPath: indexPath,
                               onTap: { [weak self] indexPath in self?.onTap(indexPath) }
                )
                cell.selectionStyle = .none
                return cell
            }
        case .hwWallet:
            let account = AccountsRepository.shared.hwVisibleAccounts[indexPath.row]
            if let cell = tableView.dequeueReusableCell(withIdentifier: "WalletListCell") as? WalletListCell {
                cell.configure(item: account,
                               indexPath: indexPath,
                               onTap: { [weak self] indexPath in self?.onTap(indexPath) }
                )
                cell.selectionStyle = .none
                return cell
            }
        default:
            break
        }

        return UITableViewCell()
    }

    func isOverviewSelected(_ account: Account) -> Bool {
        WalletsRepository.shared.get(for: account.id)?.activeSessions.count ?? 0 > 0
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.1
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

    }
}

extension DrawerNetworkSelectionViewController {
    func headerView(_ txt: String) -> UIView {
        let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: headerH))
        section.backgroundColor = .clear
        let title = UILabel(frame: .zero)
        title.text = txt
        title.numberOfLines = 0
        title.setStyle(.txtBigger)
        title.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(title)

        NSLayoutConstraint.activate([
            title.centerYAnchor.constraint(equalTo: section.centerYAnchor),
            title.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 25),
            title.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -25)
        ])

        return section
    }
}

extension DrawerNetworkSelectionViewController: UIScrollViewDelegate {
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate {
            animateShortcut()
        }
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        animateShortcut()
    }

    func animateShortcut() {

        for cell in tableView.visibleCells {
            if let c = cell as? WalletListCell,
               c.account?.id == DrawerAnimationManager.shared.accountId {
                DrawerAnimationManager.shared.accountId = nil
            }
        }
    }
}
extension DrawerNetworkSelectionViewController: DialogListViewControllerDelegate {
    func didSwitchAtIndex(index: Int, isOn: Bool, type: DialogType) {}

    func didSelectIndex(_ index: Int, with type: DialogType) {
        switch type {
        case .walletListPrefs:
            switch index {
            case 0:
                delegate?.didSelectSettings()
            case 1:
                delegate?.didSelectAbout()
            default:
                break
            }
        default:
            break
        }
    }
}
