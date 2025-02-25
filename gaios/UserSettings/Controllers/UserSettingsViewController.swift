import UIKit
import core
import gdk
import greenaddress
import hw

protocol UserSettingsViewControllerDelegate: AnyObject {
    func userLogout()
    func refresh()
}

class UserSettingsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    weak var delegate: UserSettingsViewControllerDelegate?

    var session = { WalletManager.current?.prominentSession }()
    var headerH: CGFloat = 54.0
    var viewModel = UserSettingsViewModel()
    var account: Account? { get { viewModel.wm?.account } }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "id_settings".localized
        let btn = UIBarButtonItem(image: UIImage(named: "cancel")?.maskWithColor(color: .white), style: .plain, target: self, action: #selector(self.close))
        self.navigationItem.rightBarButtonItem  = btn
        view.accessibilityIdentifier = AccessibilityIdentifiers.SettingsScreen.view

        AnalyticsManager.shared.recordView(.walletSettings, sgmt: AnalyticsManager.shared.sessSgmt(account))

        initViewModel()
    }

    func initViewModel() {
        viewModel.reloadTableView = { [weak self] in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        }
        viewModel.load()
    }

    @objc func close() {
        dismiss(animated: true, completion: nil)
    }

    func onBiometricSwitch(_ value: Bool) {
        if value == true {
            enableBioAuth()
        } else {
            disableBioAuth()
        }
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
}

extension UserSettingsViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.getCellModelsForSection(at: section)?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let vm = viewModel.getCellModel(at: indexPath)
        if let cell = tableView.dequeueReusableCell(withIdentifier: UserSettingsCell.identifier, for: indexPath) as? UserSettingsCell {
            cell.viewModel = vm
            cell.selectionStyle = .none
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case 0:
            return 0
        default:
            return headerH
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return headerView(viewModel.sections[section].rawValue.localized)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = viewModel.getCellModel(at: indexPath)
        switch item?.type {
        case .Logout:
            delegate?.userLogout()
        case .UnifiedDenominationExchange:
            showDenominationExchange()
        case .BackUpRecoveryPhrase:
            let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "OnBoardInfoViewController") as? OnBoardInfoViewController {
                vc.isSettingDisplay = true
                navigationController?.pushViewController(vc, animated: true)
            }
        case .ChangePin:
            Task {
                let credentials = try? await viewModel.wm?.prominentSession?.getCredentials(password: "")
                let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
                if let credentials = credentials, let vc = storyboard.instantiateViewController(withIdentifier: "SetPinViewController") as? SetPinViewController {
                    vc.pinFlow = .settings
                    vc.viewModel = SetPinViewModel(credentials: credentials, testnet: self.viewModel.wm?.testnet ?? false)
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
        case.LoginWithBiometrics:
            let vm = viewModel.getCellModel(at: indexPath)
            if let value = vm?.switcher {
                onBiometricSwitch(!value)
            }
        case .AutoLogout:
            showAutoLogout()
        case .TwoFactorAuthication:
            openTwoFactorAuthentication()
        case .PgpKey:
            openPgp()
        case .Version:
            break
        case .SupportID:
            Task {
                let supportId = await SupportManager.shared.str()
                await MainActor.run {
                    UIPasteboard.general.string = supportId
                    DropAlert().info(message: "id_copied_to_clipboard".localized, delay: 1.0)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        case .ArchievedAccounts:
            openArchivedAccounts()
        case .WatchOnly:
            let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "WatchOnlySettingsViewController") as? WatchOnlySettingsViewController {
                navigationController?.pushViewController(vc, animated: true)
            }
        case .GenuineCheck:
            presentGenuineCheckEndViewController()
        case .none:
            break
        }
    }
    
    @MainActor
    func presentGenuineCheckEndViewController() {
        let storyboard = UIStoryboard(name: "GenuineCheckFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "GenuineCheckEndViewController") as? GenuineCheckEndViewController {
            vc.delegate = self
            vc.model = GenuineCheckEndViewModel(bleViewModel: BleViewModel.shared)
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: true)
        }
    }
}

extension UserSettingsViewController {
    func headerView(_ txt: String) -> UIView {
        let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: headerH))
        section.backgroundColor = UIColor.gBlackBg()
        let title = UILabel(frame: .zero)
        title.font = .systemFont(ofSize: 15.0, weight: .heavy)
        title.text = txt
        title.textColor = .white.withAlphaComponent(0.4)
        title.numberOfLines = 0

        title.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(title)

        NSLayoutConstraint.activate([
            title.bottomAnchor.constraint(equalTo: section.bottomAnchor, constant: -5),
            title.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 24),
            title.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -24)
        ])

        return section
    }
}

extension UserSettingsViewController {

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
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func openTwoFactorAuthentication() {
        let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "TwoFactorAuthenticationViewController") as? TwoFactorAuthenticationViewController {
            vc.delegate = self
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

extension UserSettingsViewController {
    private func enableBioAuth() {
        guard let account = account else { return }
        // An auth key pin should be set before updating bio auth
        if !AuthenticationTypeHandler.findAuth(method: .AuthKeyPIN, forNetwork: account.keychain) {
            onAuthError(message: "id_please_enable_pin".localized)
            return
        }
        guard let session = self.session else { return }
        self.startAnimating()
        Task {
            do {
                if let credentials = try await session.getCredentials(password: "") {
                    try await account.addBiometrics(session: session, credentials: credentials)
                }
                stopAnimating()
                viewModel.load()
            } catch {
                if error is GaError {
                    self.onAuthError(message: "id_connection_failed".localized)
                } else if let err = error as? AuthenticationTypeHandler.AuthError {
                    self.onBioAuthError(message: err.localizedDescription)
                } else if !error.localizedDescription.isEmpty {
                    self.onAuthError(message: error.localizedDescription.localized)
                } else {
                    self.onAuthError(message: "id_operation_failure".localized)
                }
            }
        }
    }

    private func disableBioAuth() {
        onAuthRemoval { [weak self] in
            self?.account?.removeBioKeychainData()
            self?.viewModel.load()
        }
    }

    func onAuthRemoval(_ completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: "id_warning".localized, message: "id_your_pin_or_your_mnemonic_will".localized, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "id_cancel".localized, style: .cancel) { [weak self] _ in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        })
        alert.addAction(UIAlertAction(title: "id_ok".localized, style: .default) { _ in
            DispatchQueue.main.async {
                completionHandler()
            }
        })
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }

    func onBioAuthError(message: String) {
        let text = String(format: "id_snnreset_this_setting_and_then".localized, message)
        let alert = UIAlertController(title: "id_warning".localized, message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "id_cancel".localized, style: .default) { _ in
            self.navigationController?.popViewController(animated: true)
        })
        alert.addAction(UIAlertAction(title: "id_reset".localized, style: .destructive) { _ in
            self.account?.removeBioKeychainData()
            self.navigationController?.popViewController(animated: true)
        })
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }

    func onAuthError(message: String) {
        let alert = UIAlertController(title: "id_warning".localized, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "id_cancel".localized, style: .default) { _ in
            self.navigationController?.popViewController(animated: true)
        })
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }
}
extension UserSettingsViewController: UserSettingsViewControllerDelegate, TwoFactorAuthenticationViewControllerDelegate {
    func userLogout() {
        self.delegate?.userLogout()
    }
    func refresh() {
        self.viewModel.load()
        self.delegate?.refresh()
    }
}

extension UserSettingsViewController: DialogWatchOnlySetUpViewControllerDelegate {
    func watchOnlyDidUpdate(_ action: WatchOnlySetUpAction) {
        switch action {
        case .save, .delete:
            viewModel.load()
        default:
            break
        }
    }
}

extension UserSettingsViewController: DenominationExchangeViewControllerDelegate {
    func onDenominationExchangeSave() {
        self.viewModel.load()
        self.delegate?.refresh()
    }
}

extension UserSettingsViewController: GenuineCheckEndViewControllerDelegate {
    func onTap(_ action: GenuineCheckEndAction) {
        switch action {
        case .cancel, .continue, .diy:
            tableView.reloadData()
        case .retry:
            presentGenuineCheckEndViewController()
        case .support:
            presentDialogErrorViewController(error: HWError.Abort(""))
        case .error(let err):
            let message = err?.description()?.localized
            showError(message ?? "id_operation_failure".localized)
        }
    }

    @MainActor
    func presentDialogErrorViewController(error: Error) {
        let request = ZendeskErrorRequest(
            error: error.description()?.localized ?? "",
            network: .bitcoinSS,
            shareLogs: true,
            screenName: "FailedGenuineCheck")
        if AppSettings.shared.gdkSettings?.tor ?? false {
            self.showOpenSupportUrl(request)
            return
        }
        if let vc = UIStoryboard(name: "HelpCenter", bundle: nil)
            .instantiateViewController(withIdentifier: "ContactUsViewController") as? ContactUsViewController {
            vc.request = request
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: true, completion: nil)
        }
    }
}
