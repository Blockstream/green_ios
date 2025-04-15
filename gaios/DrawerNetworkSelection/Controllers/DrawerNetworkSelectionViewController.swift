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

        loadNavigationBtns()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateShortcut()
    }

    func setContent() {
        lblNewWallet.text = "id_setup_a_new_wallet".localized
    }

    func setStyle() {
        view.backgroundColor = UIColor.gBlackBg()
        tableView.backgroundColor = UIColor.gBlackBg()
        newWalletView.setStyle(CardStyle.defaultStyle)
    }

    func loadNavigationBtns() {
        let settingsBtn = UIButton(type: .system)
        settingsBtn.contentEdgeInsets = UIEdgeInsets(top: 7.0, left: 7.0, bottom: 7.0, right: 7.0)
        settingsBtn.setImage(UIImage(named: "ic_gear"), for: .normal)
//        settingsBtn.addTarget(self, action: #selector(settingsBtnTapped), for: .touchUpInside)
        let aboutBtn = UIButton(type: .system)
        aboutBtn.contentEdgeInsets = UIEdgeInsets(top: 7.0, left: 7.0, bottom: 7.0, right: 7.0)
        aboutBtn.setImage(UIImage(named: "ic_tab_security"), for: .normal)
//        aboutBtn.addTarget(self, action: #selector(aboutBtnTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItems = [UIBarButtonItem(customView: settingsBtn), UIBarButtonItem(customView: aboutBtn)]
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
        newWalletView.pressAnimate {
            self.delegate?.didSelectAddWallet()
        }
    }

    @IBAction func btnAbout(_ sender: Any) {
        delegate?.didSelectAbout()
    }

    @IBAction func btnSettings(_ sender: Any) {
        delegate?.didSelectSettings()
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
            return headerView("id_digital_wallets".localized)
        case .ephWallet:
            if ephAccounts.isEmpty {
                return nil
            }
            return headerView("id_ephemeral_wallets".localized)
        case .hwWallet:
            if AccountsRepository.shared.hwVisibleAccounts.isEmpty {
                return nil
            }
            return headerView("id_hardware_wallets".localized)
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
