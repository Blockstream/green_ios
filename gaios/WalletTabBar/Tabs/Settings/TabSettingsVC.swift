import UIKit
import core
import gdk
import greenaddress
import hw

class TabSettingsVC: TabViewController {

    @IBOutlet weak var tableView: UITableView!

    var session = { WalletManager.current?.prominentSession }()
    var viewModel = TabSettingsModel()
    var account: Account? { get { viewModel.wm?.account } }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.gBlackBg()

        initViewModel()
        register()
        setContent()
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
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {[weak self] in
            self?.tableView.refreshControl?.endRefreshing()
        }
    }

    func initViewModel() {
        viewModel.reloadTableView = { [weak self] in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        }
        viewModel.load()
    }
    func getSwitchValue() -> Bool {
        guard let screenlock = session?.settings?.getScreenLock() else {
            DropAlert().error(message: "id_operation_failure".localized)
            return false
        }
        if screenlock == .None {
            return false
        } else if screenlock == .All {
            return true
        } else if screenlock == .FaceID || screenlock == .TouchID {
            // this should never happen
            logger.info("no pin exists but faceid/touchid is enabled" )
            return true
        } else if screenlock == .Pin {
            return false
        }
        return false
    }
    func comingSoon() {
        let alert = UIAlertController(title: "Coming soon...", message: "", preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
extension TabSettingsVC: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.getCellModelsForSection(at: section)?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        switch TabSettingsSection(rawValue: indexPath.section) {

        case .header:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TabHeaderCell.identifier, for: indexPath) as? TabHeaderCell {
                cell.configure(title: "Settings".localized, icon: walletModel.headerIcon, tab: .settings, onTap: {[weak self] in
                    self?.walletTab.switchNetwork()
                })
                cell.selectionStyle = .none
                return cell
            }
        default:
            let vm = viewModel.getCellModel(at: indexPath)
            if let cell = tableView.dequeueReusableCell(withIdentifier: SettingsCell.identifier, for: indexPath) as? SettingsCell {
                cell.viewModel = vm
                cell.selectionStyle = .none
                return cell
            }
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch TabSettingsSection(rawValue: section) {
        case .header:
            return 0.1
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

        switch viewModel.sections[section] {
        case .header:
            return nil
        case .general:
            return sectionHeader("id_general".localized)
        case .wallet:
            return sectionHeader("id_wallet".localized)
        case .twoFactor:
            return sectionHeader("2FA Account".localized)
        case .about:
            return sectionHeader("id_about".localized)
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        tableView.deselectRow(at: indexPath, animated: true)
        let item = viewModel.getCellModel(at: indexPath)
        switch item?.type {
        case .header:
            return
        case .support:
            walletTab.presentContactUsViewController(request: ZendeskErrorRequest(shareLogs: true), isPush: true)
        case .unifiedDenominationExchange:
            showDenominationExchange()
        case .logout:
            walletTab.userLogout()
        case .rename:
            walletTab.rename()
        case .lightning:
            comingSoon()
        case .ampID:
            comingSoon()
        case .autoLogout:
            showAutoLogout()
        case .twoFactorAuthication:
            openTwoFactorAuthentication()
        case .pgpKey:
            openPgp()
        case .version:
            break
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
            openArchivedAccounts()
        case .watchOnly:
            let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "WatchOnlySettingsViewController") as? WatchOnlySettingsViewController {
                navigationController?.pushViewController(vc, animated: true)
            }
        case .none:
            break
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

extension TabSettingsVC {

    func showAlert(_ error: Error) {
        let text: String
        if let error = error as? TwoFactorCallError {
            switch error {
            case .failure(let localizedDescription), .cancel(let localizedDescription):
                text = localizedDescription
            }
            self.showError(text)
        }
    }

    func openPgp() {
        let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "PgpViewController") as? PgpViewController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func openArchivedAccounts() {
        let storyboard = UIStoryboard(name: "Accounts", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AccountArchiveViewController") as? AccountArchiveViewController {
            vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func openTwoFactorAuthentication() {
        let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "TwoFactorAuthenticationViewController") as? TwoFactorAuthenticationViewController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func showDenominationExchange() {
        let ltFlow = UIStoryboard(name: "DenominationExchangeFlow", bundle: nil)
        if let vc = ltFlow.instantiateViewController(withIdentifier: "DenominationExchangeViewController") as? DenominationExchangeViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            self.present(vc, animated: false, completion: nil)
        }
    }

    func showAutoLogout() {
        guard let settings = session?.settings else { return }
        let list = [AutoLockType.minute.string, AutoLockType.twoMinutes.string, AutoLockType.fiveMinutes.string, AutoLockType.tenMinutes.string, AutoLockType.sixtyMinutes.string]
        let selected = settings.autolock.string
        let alert = UIAlertController(title: "id_auto_logout_timeout".localized, message: "", preferredStyle: .actionSheet)
        list.forEach { (item: String) in
            alert.addAction(UIAlertAction(title: item, style: item == selected  ? .destructive : .default) { _ in
                settings.autolock = AutoLockType.from(item)
                Task {
                    self.startAnimating()
                    do {
                        _ = try await self.session?.changeSettings(settings: settings)
                        await MainActor.run {
                            self.viewModel.load()
                        }
                    } catch {
                        self.showError(error)
                    }
                    self.stopAnimating()
                }
            })
        }
        alert.addAction(UIAlertAction(title: "id_cancel".localized, style: .cancel) { _ in })
        self.present(alert, animated: true, completion: nil)
    }
}

extension TabSettingsVC: DialogWatchOnlySetUpViewControllerDelegate {
    func watchOnlyDidUpdate(_ action: WatchOnlySetUpAction) {
        switch action {
        case .save, .delete:
            viewModel.load()
        default:
            break
        }
    }
}

extension TabSettingsVC: DenominationExchangeViewControllerDelegate {
    func onDenominationExchangeSave() {
        self.viewModel.load()
    }
}
extension TabSettingsVC: AccountArchiveViewControllerDelegate {
    func archiveDidChange() {
        viewModel.load()
        tableView.reloadData()
    }
}
