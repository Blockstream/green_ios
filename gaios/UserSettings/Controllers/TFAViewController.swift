import UIKit
import core
import gdk

protocol TFAViewControllerDelegate: AnyObject {
    func sendLogout()
}

class TFAViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    var viewModel = TFAViewModel()
    var sectionHeaderH: CGFloat = 54.0
    weak var delegate: TFAViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.gBlackBg()

        register()
        setContent()
        AnalyticsManager.shared.recordView(.walletSettings2FA, sgmt: AnalyticsManager.shared.sessSgmt(AccountsRepository.shared.current))
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }
    func setContent() {
        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl!.tintColor = UIColor.white
        tableView.refreshControl!.addTarget(self, action: #selector(pull(_:)), for: .valueChanged)
    }
    func register() {
        ["TFAHeaderCell", "AlertCardCell", "TFACell", "TFATimeCell", "TFAActionsCell", "TFANetworkSelectCell", "TFAMethodCell", "TFAEmptyCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
    }
    @objc func pull(_ sender: UIRefreshControl? = nil) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {[weak self] in
            self?.tableView.refreshControl?.endRefreshing()
        }
    }
    func reload() {
        Task {
            let res = try? await viewModel.getTwoFactors()
            viewModel.factors = res
            UIView.transition(with: tableView, duration: 0.3, options: .transitionCrossDissolve, animations: {self.tableView.reloadData()}, completion: nil)
        }
    }
    func setCsvTimeLock(csv: CsvTime) {
        self.startLoader()
        Task {
            do {
                try await viewModel.setCsvTimeLock(csv: csv)
                reload()
                DropAlert().success(message: String(format: "%@: %@", "id_twofactor_authentication_expiry".localized, csv.label()))
            } catch {
                if let twofaError = error as? TwoFactorCallError {
                    switch twofaError {
                    case .failure(let localizedDescription), .cancel(let localizedDescription):
                        DropAlert().error(message: localizedDescription)
                    }
                } else {
                    DropAlert().error(message: "Error changing csv time")
                }
            }
            stopLoader()
        }
    }
    func showResetTwoFactor() {
        let hint = "jane@example.com"
        let alert = UIAlertController(title: "id_request_twofactor_reset".localized, message: "id_resetting_your_twofactor_takes".localized, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = hint
            textField.keyboardType = .emailAddress
        }
        alert.addAction(UIAlertAction(title: "id_cancel".localized, style: .cancel) { _ in })
        alert.addAction(UIAlertAction(title: "id_save".localized, style: .default) { _ in
            let textField = alert.textFields!.first
            let email = textField!.text
            self.resetTwoFactor(email: email!)
        })
        self.present(alert, animated: true, completion: nil)
    }
    func resetTwoFactor(email: String) {
        startLoader()
        Task {
            do {
                try await self.viewModel.resetTwoFactor(session: self.viewModel.session, email: email)
                self.reload()
                DropAlert().success(message: "id_2fa_reset_in_progress".localized)
                let notification = NSNotification.Name(rawValue: EventType.TwoFactorReset.rawValue)
                NotificationCenter.default.post(name: notification, object: nil, userInfo: nil)
                self.delegate?.sendLogout()
            } catch {
                if let twofaError = error as? TwoFactorCallError {
                    switch twofaError {
                    case .failure(let localizedDescription), .cancel(let localizedDescription):
                        self.showError(localizedDescription)
                    }
                } else {
                    DropAlert().error(message: error.localizedDescription)
                }
            }
            stopLoader()
        }
    }
    func onReset2fa() {
        showResetTwoFactor()
    }
    func on2faThreshold() {
        let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "TwoFactorLimitViewController") as? TwoFactorLimitViewController {
            vc.session = viewModel.session
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func onRecoveryTool() {
        if let url = URL(string: "https://github.com/greenaddress/garecovery") {
            SafeNavigationManager.shared.navigate(url)
        }
    }
    func onRecoveryTransactions() {
        let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "RecoveryTransactionsViewController") as? RecoveryTransactionsViewController {
            vc.viewModel = RecoveryTransactionsViewModel(session: viewModel.session)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func disable(_ type: TwoFactorType) {
        self.startLoader()
        Task {
            do {
                try await viewModel.disable(type: type)
                self.reload()
                let notification = NSNotification.Name(rawValue: EventType.TwoFactorReset.rawValue)
                NotificationCenter.default.post(name: notification, object: nil, userInfo: nil)
            } catch {
                if let twofaError = error as? TwoFactorCallError {
                    switch twofaError {
                    case .failure(let localizedDescription), .cancel(let localizedDescription):
                        DropAlert().error(message: localizedDescription.localized)
                    }
                } else {
                    DropAlert().error(message: error.localizedDescription)
                }
            }
            stopLoader()
        }
    }
}
extension TFAViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.sections.count
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch viewModel.sections[section] {
        case .header, .warnMulti, .networkSelect, .infoExpire, .reset, .threshold, .recActions:
            return 1
        case .methods:
            return viewModel.factors?.count ?? 0
        case .empty:
            if let factors = viewModel.factors {
                return factors.count == 0 ? 1 : 0
            } else {
                return 0
            }
        case .expiry:
            return viewModel.csvTypes.count
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch viewModel.sections[indexPath.section] {
        case .header:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TFAHeaderCell.identifier, for: indexPath) as? TFAHeaderCell {
                cell.configure()
                cell.selectionStyle = .none
                return cell
            }
        case .networkSelect:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TFANetworkSelectCell.identifier, for: indexPath) as? TFANetworkSelectCell {
                cell.configure(networks: viewModel.networks, onChange: { [weak self] value in
                    self?.viewModel.selectedSegmentIndex = value
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) {
                        self?.reload()
                    }
                })
                cell.selectionStyle = .none
                return cell
            }
        case .methods:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TFAMethodCell.identifier) as? TFAMethodCell, let factors = viewModel.factors {
                let item: TwoFactorItem = factors[indexPath.row]
                cell.configure(item)
                cell.selectionStyle = .none
                return cell
            }
        case .empty:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TFAEmptyCell.identifier, for: indexPath) as? TFAEmptyCell {
                cell.configure(isLiquid: viewModel.session.gdkNetwork.liquid)
                cell.selectionStyle = .none
                return cell
            }
        case .reset:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TFACell.identifier, for: indexPath) as? TFACell {
                cell.configure(title: "I lost my 2FA method".localized)
                cell.selectionStyle = .none
                return cell
            }
        case .threshold:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TFACell.identifier, for: indexPath) as? TFACell {
                cell.configure(title: "Two-Factor threshold".localized, hint: viewModel.threshold)
                cell.selectionStyle = .none
                return cell
            }
        case .warnMulti:
            if let cell = tableView.dequeueReusableCell(withIdentifier: "AlertCardCell", for: indexPath) as? AlertCardCell {
                let model = AlertCardCellModel(type: .TFAWarnMulti)
                cell.configure(model, onLeft: nil, onRight: nil, onDismiss: nil)
                return cell
            }
        case .expiry:
            let item: CsvTime = viewModel.csvTypes[indexPath.row]
            if let cell = tableView.dequeueReusableCell(withIdentifier: "TFATimeCell") as? TFATimeCell {
                cell.configure(item: item, current: viewModel.session.settings?.csvtime, gdkNetwork: viewModel.session.gdkNetwork)
                cell.selectionStyle = .none
                return cell
            }
        case .infoExpire:
            if let cell = tableView.dequeueReusableCell(withIdentifier: "AlertCardCell", for: indexPath) as? AlertCardCell {
                let model = AlertCardCellModel(type: .TFAInfoExpire)
                cell.configure(model, onLeft: nil, onRight: nil, onDismiss: nil)
                return cell
            }
        case .recActions:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TFAActionsCell.identifier, for: indexPath) as? TFAActionsCell {
                cell.configure(onRecTool: { [weak self] in
                    self?.onRecoveryTool()
                }, onRecTxs: { [weak self] in
                    self?.onRecoveryTransactions()
                })
                return cell
            }
        }
        return UITableViewCell()
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch viewModel.sections[section] {
        case .header, .warnMulti, .methods, .empty, .infoExpire, .recActions:
            return 0.1
        case .networkSelect, .reset, .threshold, .expiry:
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
        case .header, .warnMulti, .methods, .empty, .infoExpire, .recActions:
            return nil
        case .networkSelect:
            return sectionHeader("2FA Methods".localized)
        case .reset:
            return sectionHeader("Request Two-Factor reset".localized)
        case .threshold:
            return sectionHeader("2FA Threshold".localized)
        case .expiry:
            return sectionHeader("2FA Expiry".localized)
        }
    }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch viewModel.sections[indexPath.section] {
        case .header, .warnMulti, .networkSelect:
            return
        case .methods:
            guard let factors = viewModel.factors else { return }
            let selectedFactor: TwoFactorItem = factors[indexPath.row]
            if selectedFactor.enabled {
                disable(selectedFactor.type)
                return
            }
            switch selectedFactor.type {
            case .email:
                let storyboard = UIStoryboard(name: "AuthenticatorFactors", bundle: nil)
                if let vc = storyboard.instantiateViewController(withIdentifier: "SetEmailViewController") as? SetEmailViewController {
                    vc.session = viewModel.session
                    navigationController?.pushViewController(vc, animated: true)
                }
            case .sms:
                let storyboard = UIStoryboard(name: "AuthenticatorFactors", bundle: nil)
                if let vc = storyboard.instantiateViewController(withIdentifier: "SetPhoneViewController") as? SetPhoneViewController {
                    vc.sms = true
                    vc.network = viewModel.session.networkType
                    navigationController?.pushViewController(vc, animated: true)
                }
            case .phone:
                let storyboard = UIStoryboard(name: "AuthenticatorFactors", bundle: nil)
                if let vc = storyboard.instantiateViewController(withIdentifier: "SetPhoneViewController") as? SetPhoneViewController {
                    vc.phoneCall = true
                    vc.network = viewModel.session.networkType
                    navigationController?.pushViewController(vc, animated: true)
                }
            case .gauth:
                let storyboard = UIStoryboard(name: "AuthenticatorFactors", bundle: nil)
                if let vc = storyboard.instantiateViewController(withIdentifier: "SetGauthViewController") as? SetGauthViewController {
                    vc.session = viewModel.session
                    navigationController?.pushViewController(vc, animated: true)
                }
            }
        case .empty:
            return
        case .reset:
            onReset2fa()
        case .threshold:
            on2faThreshold()
        case .expiry:
            let selected = viewModel.csvTypes[indexPath.row]
            if let newCsv = selected.value(for: viewModel.session.gdkNetwork),
               let index = viewModel.csvValues.firstIndex(of: newCsv),
               newCsv != viewModel.session.settings?.csvtime ?? 0 {
                setCsvTimeLock(csv: viewModel.csvTypes[index])
            } else {
                self.showAlert(title: "id_error".localized, message: "id_select_a_new_value_to_change_csv".localized)
            }
        case .infoExpire, .recActions:
            return
        }
    }
}
extension TFAViewController {
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
