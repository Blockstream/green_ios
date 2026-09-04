import UIKit
import core

import greenaddress
import hw

class TabSettingsVC: TabViewController {

    @IBOutlet weak var tableView: UITableView!
    let viewModel: TabSettingsVM
    private var settingsCoordinator: SettingsCoordinator? { walletTab.settingsCoordinator }

    init?(coder: NSCoder, viewModel: TabSettingsVM) {
        self.viewModel = viewModel
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("You must create this view controller with a view model.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.gBlackBg()
        register()
        setContent()
        attachCoordinator()
        viewModel.onUpdate = { [weak self] feature in
            DispatchQueue.main.async {
                self?.onUpdate(feature: feature)
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        attachCoordinator()
    }

    private func attachCoordinator() {
        walletTab.attachSettingsCoordinator()
    }

    func onUpdate(feature: RefreshFeature?) {
        switch feature {
        case .settings:
            if tableView?.refreshControl?.isRefreshing == true {
                tableView?.refreshControl?.endRefreshing()
            }
            tableView?.reloadData()
        default:
            break
        }
    }

    func setContent() {
        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl!.tintColor = UIColor.white
        tableView.refreshControl!.addTarget(self, action: #selector(pull(_:)), for: .valueChanged)
    }

    func register() {
        ["TabHeaderCell", "SettingsCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
    }
    @objc func pull(_ sender: UIRefreshControl? = nil) {
        viewModel.refresh(features: [.settings])
    }
}
extension TabSettingsVC: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        logger.info("TabSettingsVC numberOfSections \(self.viewModel.settings.count)")
        return viewModel.settings.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.settings[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch viewModel.settings[indexPath.section].section {
        case .header:
            let headerIcon = UIImage(named: viewModel.mainWallet.gdkNetwork.mainnet ? "ic_wallet" : "ic_wallet_testnet")?.maskWithColor(color: .white)
            if let cell = tableView.dequeueReusableCell(withIdentifier: TabHeaderCell.identifier, for: indexPath) as? TabHeaderCell, let headerIcon {
                cell.configure(title: "id_settings".localized, icon: headerIcon, tab: .settings, onTap: {[weak self] in
                    self?.walletTab.switchNetwork()
                })
                cell.selectionStyle = .none
                return cell
            }
        default:
            if let cell = tableView.dequeueReusableCell(withIdentifier: SettingsCell.identifier, for: indexPath) as? SettingsCell {
                let settingItem = viewModel.settings[indexPath.section].items[indexPath.row]
                let cellModel = viewModel.getSettingsItemCellModel(for: settingItem)
                cell.viewModel = cellModel
                cell.selectionStyle = .none
                return cell
            }
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch viewModel.settings[section].section {
        case .header:
            return 0.1
        case .support:
            return 20
        default:
            return sectionHeaderH
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.1
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch viewModel.settings[section].section {
        case .header:
            return nil
        case .wallet:
            return sectionHeader("id_wallet_settings".localized)
        case .account:
            return sectionHeader("id_account_settings".localized)
        case .about:
            return sectionHeader("id_about".localized)
        case .support:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        attachCoordinator()
        guard let coordinator = settingsCoordinator else { return }
        let item = viewModel.settings[indexPath.section].items[indexPath.row]
        switch item {
        case .header, .version:
            return
        case .support:
            coordinator.navigate(to: .contactSupport(ZendeskErrorRequest(shareLogs: true)))
        case .unifiedDenominationExchange:
            coordinator.navigate(to: .denominationExchange(coordinator.denominationExchangeViewModel()))
        case .logout:
            coordinator.navigate(to: .logout)
        case .rename:
            coordinator.navigate(to: .rename)
        case .lightning:
            if coordinator.hasLightning(), let model = coordinator.lightningDetailsViewModel() {
                coordinator.navigate(to: .lightningDetails(model))
            } else {
                coordinator.navigate(to: .lightningCreate(coordinator.lightningCreateViewModel()))
            }
        case .ampID:
            coordinator.navigate(to: .amp(coordinator.dialogAmpViewModel()))
        case .autoLogout:
            if let model = coordinator.dialogAutoLogoutViewModel() {
                coordinator.navigate(to: .autologout(model))
            }
        case .twoFactorAuthication:
            coordinator.navigate(to: .twoFactorAuth(coordinator.tfaViewModel()))
        case .pgpKey:
            coordinator.navigate(to: .pgp(coordinator.pgpViewModel()))
        case .supportID:
            Task {
                let supportId = await SupportManager.shared.str()
                await MainActor.run {
                    UIPasteboard.general.string = supportId
                    DropAlert().info(message: "id_copied_to_clipboard".localized, delay: 1.0)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        case .archievedAccounts:
            coordinator.navigate(to: .archivedAccounts)
        case .watchOnly:
            coordinator.navigate(to: .watchonly(coordinator.watchOnlySettingsViewModel()))
        case .createAccount:
            coordinator.navigate(to: .createAccount(coordinator.createAccountViewModel()))
        case .swaps:
            coordinator.navigate(to: .jadeBoltzSwap(coordinator.jadeBoltzSwapViewModel()))
        case .rescanSwaps:
            Task { await self.rescanSwaps() }
        }
    }

    func rescanSwaps() async {
        startLoader(message: "Processing stuck swaps...".localized)
        let task = Task { [weak self] in
            try await self?.viewModel.rescanSwaps()
        }
        switch await task.result {
        case .success:
            stopLoader()
            DropAlert().success(message: "Swaps Processed")
        case .failure(let err):
            stopLoader()
            showError(err.description().localized)
        }
    }
}
extension TabSettingsVC {
    func sectionHeader(_ txt: String) -> UIView {

        let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: sectionHeaderH))
        section.backgroundColor = UIColor.clear
        let title = UILabel(frame: .zero)
        title.setStyle(.txtSectionHeader)
        title.text = txt
        title.textColor = UIColor.gGrayTxt()
        title.numberOfLines = 0

        title.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(title)

        NSLayoutConstraint.activate([
            title.centerYAnchor.constraint(equalTo: section.centerYAnchor, constant: 10.0),
            title.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 25),
            title.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: 20)
        ])

        return section
    }
}
