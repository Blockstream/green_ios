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

    var onSelection: ((Account) -> Void)?
    weak var delegate: DrawerNetworkSelectionDelegate?

    var headerH: CGFloat = 44.0
    var footerH: CGFloat = 54.0
    var isAnimating = false

    private var ephAccounts: [Account] {
        AccountsRepository.shared.ephAccounts.filter { account in
            account.isEphemeral && !WalletsRepository.shared.wallets.filter {$0.key == account.id }.isEmpty
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()

        tableView.register(UINib(nibName: "WalletListCell", bundle: nil), forCellReuseIdentifier: "WalletListCell")

        view.accessibilityIdentifier = AccessibilityIdentifiers.DrawerMenuScreen.view
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateShortcut()
    }

    func setContent() {
        btnSettings.setTitle(NSLocalizedString("id_app_settings", comment: ""), for: .normal)
        btnSettings.setTitleColor(.lightGray, for: .normal)
        btnAbout.setTitle(NSLocalizedString("id_about", comment: ""), for: .normal)
        btnAbout.setImage(UIImage(named: "ic_about")!, for: .normal)
        btnAbout.setTitleColor(.lightGray, for: .normal)
        lblNewWallet.text = "id_setup_a_new_wallet".localized
    }

    func setStyle() {
        newWalletView.cornerRadius = 5.0
    }

    func getAccountFromTableView(_ indexPath: IndexPath) -> Account? {
        switch HomeSection(rawValue: indexPath.section) {
        case .swWallet:
            return AccountsRepository.shared.swAccounts[indexPath.row]
        case .ephWallet:
            return ephAccounts[indexPath.row]
        case .hwWallet:
            return AccountsRepository.shared.hwVisibleAccounts[indexPath.row]
        default:
            return nil
        }
    }

    func goAccount(account: Account) {
        if let wm = WalletsRepository.shared.get(for: account.id), wm.logged {
            AccountNavigator.goLogged(account: account)
        } else {
            AccountNavigator.goLogin(account: account)
        }
    }

    func onTap(_ indexPath: IndexPath) {
        onTapOverview(indexPath)
    }

    func onTapOverview(_ indexPath: IndexPath) {
        if let account = getAccountFromTableView(indexPath) {
            goAccount(account: account)
            dismiss(animated: true, completion: nil)
        }
    }

    func onTapLightShort(_ indexPath: IndexPath) {
        if let account = getAccountFromTableView(indexPath) {
            if let lightning = account.getDerivedLightningAccount() {
                goAccount(account: lightning)
                dismiss(animated: true, completion: nil)
            }
        }
    }
    @IBAction func btnAddWallet(_ sender: Any) {
        delegate?.didSelectAddWallet()
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func btnAbout(_ sender: Any) {
        delegate?.didSelectAbout()
    }

    @IBAction func btnSettings(_ sender: Any) {
        delegate?.didSelectSettings()
    }
}

extension DrawerNetworkSelectionViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch HomeSection(rawValue: section) {
        case .swWallet:
            return AccountsRepository.shared.swAccounts.count
        case .ephWallet:
            return ephAccounts.count
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
                               isOverviewSelected: isOverviewSelected(account),
                               isLightningSelected: isLightningSelected(account),
                               indexPath: indexPath,
                               onLongpress: nil,
                               onTap: { [weak self] indexPath in self?.onTap(indexPath) },
                               onTapOverview: { [weak self] indexPath in self?.onTapOverview(indexPath) },
                               onTapLightShort: { [weak self] indexPath in self?.onTapLightShort(indexPath) }
                )
                cell.selectionStyle = .none
                return cell
            }
        case .ephWallet:
            let account = ephAccounts[indexPath.row]
            if let cell = tableView.dequeueReusableCell(withIdentifier: "WalletListCell") as? WalletListCell {
                cell.configure(item: account,
                               isOverviewSelected: isOverviewSelected(account),
                               isLightningSelected: isLightningSelected(account),
                               indexPath: indexPath,
                               onLongpress: nil,
                               onTap: { [weak self] indexPath in self?.onTap(indexPath) },
                               onTapOverview: { [weak self] indexPath in self?.onTapOverview(indexPath) },
                               onTapLightShort: { [weak self] indexPath in self?.onTapLightShort(indexPath) }
                )
                cell.selectionStyle = .none
                return cell
            }
        case .hwWallet:
            let account = AccountsRepository.shared.hwVisibleAccounts[indexPath.row]
            if let cell = tableView.dequeueReusableCell(withIdentifier: "WalletListCell") as? WalletListCell {
                cell.configure(item: account,
                               isOverviewSelected: isOverviewSelected(account),
                               isLightningSelected: isLightningSelected(account),
                               indexPath: indexPath,
                               onLongpress: nil,
                               onTap: { [weak self] indexPath in self?.onTap(indexPath) },
                               onTapOverview: { [weak self] indexPath in self?.onTapOverview(indexPath) },
                               onTapLightShort: { [weak self] indexPath in self?.onTapLightShort(indexPath) }
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

    func isLightningSelected(_ account: Account) -> Bool {
        if let account = account.getDerivedLightningAccount() {
            return WalletsRepository.shared.get(for: account.id)?.activeSessions.count ?? 0 > 0
        }
        return false
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch HomeSection(rawValue: section) {
        case .ephWallet:
            if ephAccounts.isEmpty {
                return 0.1
            }
        case .swWallet:
            if AccountsRepository.shared.swAccounts.isEmpty {
                return 0.1
            }
        case .hwWallet:
            if AccountsRepository.shared.hwVisibleAccounts.isEmpty {
                return 0.1
            }
        case .remoteAlerts:
            return 0.1
        default:
            break
        }
        return headerH
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch HomeSection(rawValue: section) {
        case .swWallet:
            if AccountsRepository.shared.swAccounts.isEmpty {
                return nil
            }
            return headerView(NSLocalizedString("id_digital_wallets", comment: ""))
        case .ephWallet:
            if ephAccounts.isEmpty {
                return nil
            }
            return headerView(NSLocalizedString("id_ephemeral_wallets", comment: ""))
        case .hwWallet:
            if AccountsRepository.shared.hwVisibleAccounts.isEmpty {
                return nil
            }
            return headerView(NSLocalizedString("id_hardware_wallets", comment: ""))
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

    }
}

extension DrawerNetworkSelectionViewController {
    func headerView(_ txt: String) -> UIView {
        let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: headerH))
        section.backgroundColor = UIColor.customTitaniumDark()
        let title = UILabel(frame: .zero)
        title.font = .systemFont(ofSize: 14.0, weight: .semibold)
        title.text = txt
        title.textColor = UIColor.customGrayLight()
        title.numberOfLines = 0

        title.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(title)

        NSLayoutConstraint.activate([
            title.centerYAnchor.constraint(equalTo: section.centerYAnchor),
            title.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 20),
            title.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -20)
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
            if let c = cell as? WalletListCell, c.hasShortcut == true,
               c.account?.id == DrawerAnimationManager.shared.accountId {

                DrawerAnimationManager.shared.accountId = nil
                UIView.animate(withDuration: 0.5, animations: {
                    c.shortcutView.backgroundColor = UIColor.gLightning()
                }, completion: { completed in
                    UIView.animate(withDuration: 1.0, animations: {
                        c.shortcutView.backgroundColor = UIColor.clear
                    }, completion: { completed in
                        self.isAnimating = false
                    })
                })
            }
        }
    }
}
