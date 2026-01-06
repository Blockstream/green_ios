import UIKit
import core
import gdk
import greenaddress
import hw

class TabSettingsVC: TabViewController {

    @IBOutlet weak var tableView: UITableView!

    var session = { WalletManager.current?.prominentSession }()
    var viewModel = TabSettingsModel()
    var account: Account? { get { walletModel.mainAccount } }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.gBlackBg()

        register()
        setContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        initViewModel()
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
        viewModel.load()
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
        alert.addAction(UIAlertAction(title: "id_ok".localized, style: UIAlertAction.Style.default, handler: nil))
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
                cell.configure(title: "id_settings".localized, icon: walletModel.headerIcon, tab: .settings, onTap: {[weak self] in
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
        switch viewModel.sections[section] {
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

        switch viewModel.sections[section] {
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
            if viewModel.hasLightning() {
                openLTSettingsViewController()
            } else {
                openLTCreateViewController()
            }
        case .ampID:
            if !viewModel.hasSubaccountAmp() {
                presentDialogCreateAmp()
            } else if viewModel.getSubaccountsAmp().count == 1, let subaccount = viewModel.getSubaccountsAmp().first {
                presentDialogAmpId(subaccount)
            } else {
                presentDialogAccountsViewController()
            }
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
        case .createAccount:
            createAccount()
        case .none:
            break
        }
    }

    func createSubaccountAmp() async {
        startLoader(message: String(format: "id_creating_your_s_account".localized, "AMP"))
        let task = Task { [weak self] in
            try await self?.viewModel.createSubaccountAmp()
        }
        switch await task.result {
        case .success:
            stopLoader()
            if let subaccount = viewModel.getSubaccountsAmp().first {
                presentDialogAmpId(subaccount)
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: EventType.newSubaccount.rawValue), object: nil, userInfo: nil)
            }
        case .failure(let err):
            stopLoader()
            showError(err.description().localized)
        }
    }

    @MainActor
    func presentDialogAccountsViewController() {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogAccountsViewController") as? DialogAccountsViewController {
            vc.viewModel = viewModel.dialogAccountsModel()
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @MainActor
    func presentDialogCreateAmp() {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogActionsViewController") as? DialogActionsViewController {
            vc.viewModel = DialogActionsViewModel(
                title: "id_create_an_amp_account".localized,
                description: "id_amp_accounts_allow_you_to_send".localized,
                confirm: "id_create_an_amp_account".localized,
                link: "id_learn_more".localized)
            vc.delegate = { action in
                switch action {
                case .confirm:
                    Task { [weak self] in
                        await self?.createSubaccountAmp()
                    }
                case .link:
                    let url = "https://help.blockstream.com/hc/en-us/articles/900003418286"
                    if let url = URL(string: url) {
                        if UIApplication.shared.canOpenURL(url) {
                            SafeNavigationManager.shared.navigate(url)
                        }
                    }
                }
            }
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }
    @MainActor
    func presentDialogAmpId(_ subaccount: WalletItem) {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogActionsViewController") as? DialogActionsViewController {
            vc.viewModel = DialogActionsViewModel(
                title: subaccount.name,
                description: "id_your_amp_account_is_set_up_and".localized,
                confirm: "id_copy_amp_id".localized,
                link: "id_learn_more".localized)
            vc.delegate = { action in
                switch action {
                case .confirm:
                    self.copyAmpId(subaccount)
                case .link:
                    let url = "https://help.blockstream.com/hc/en-us/articles/900003418286"
                    if let url = URL(string: url) {
                        if UIApplication.shared.canOpenURL(url) {
                            SafeNavigationManager.shared.navigate(url)
                        }
                    }
                }
            }
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @MainActor
    func copyAmpId(_ subaccount: WalletItem) {
        UIPasteboard.general.string = subaccount.receivingId
        DropAlert().info(message: "id_copied_to_clipboard".localized)
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

    func createAccount() {
        let storyboard = UIStoryboard(name: "Utility", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SecuritySelectViewController") as? SecuritySelectViewController {
            vc.viewModel = SecuritySelectViewModel(asset: "btc")
            // vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func openLTSettingsViewController() {
        guard let lightningSession = viewModel.wm?.lightningSession else {
            DropAlert().warning(message: "Create a lightning account")
            return
        }
        let storyboard = UIStoryboard(name: "LTFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "LTSettingsViewController") as? LTSettingsViewController {
            vc.viewModel = LTSettingsViewModel(lightningSession: lightningSession, hideActions: false)
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func openLTCreateViewController() {
        let storyboard = UIStoryboard(name: "LTFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "LTCreateViewController") as? LTCreateViewController {
            vc.viewModel = LTCreateViewModel()
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func openTwoFactorAuthentication() {
        let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "TFAViewController") as? TFAViewController {
            vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        }
//        let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
//        if let vc = storyboard.instantiateViewController(withIdentifier: "TwoFactorAuthenticationViewController") as? TwoFactorAuthenticationViewController {
//            navigationController?.pushViewController(vc, animated: true)
//        }
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

        let dialogViewModel = DialogListViewModel(
            title: "id_auto_logout_timeout".localized,
            type: .autoLogoutPrefs,
            items: list
                .enumerated()
                .map { index, element in AutoLogoutCellModel(
                    title: element,
                    index: index,
                    selected: element == settings.autolock.string,
                    onSelected: { [weak self] index in
                        guard let self = self else { return }
                        settings.autolock = AutoLockType.from(list[index])
                        Task {
                            self.startAnimating()
                            do {
                                _ = try await self.session?.changeSettings(settings: settings)
                                await MainActor.run {
                                    self.viewModel.load()
                                    self.dismiss(animated: true)
                                }
                            } catch {
                                self.showError(error)
                            }
                            self.stopAnimating()
                        }
                    }
                )
            })

        let dialogStoryboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let dialogViewController = dialogStoryboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {
            dialogViewController.viewModel = dialogViewModel
            dialogViewController.modalPresentationStyle = .overFullScreen
            self.present(dialogViewController, animated: true, completion: nil)
        }
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
        walletModel.reloadBalances()
        walletTab.updateTabs([.home, .transact])
    }
}

extension TabSettingsVC: AccountArchiveViewControllerDelegate {
    func archiveDidChange() {
        Task { [weak self] in
            await self?.walletTab.reload(discovery: false)
        }
    }
}

extension TabSettingsVC: DialogAccountsViewControllerDelegate {
    func didSelectAccount(_ walletItem: WalletItem?) {
        if let walletItem = walletItem {
            presentDialogAmpId(walletItem)
        }
    }
}
extension TabSettingsVC: TFAViewControllerDelegate {
    func sendLogout() {
        walletTab.userLogout()
    }
}
