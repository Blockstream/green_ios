import UIKit
import core

protocol AppSettingsViewControllerDelegate: AnyObject {
    // func sendLogout()
}

class AppSettingsViewController: KeyboardViewController {

    @IBOutlet weak var tableView: UITableView!

    var viewModel = AppSettingsViewModel()
    var sectionHeaderH: CGFloat = 54.0
    weak var delegate: AppSettingsViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.gBlackBg()
        title = "id_app_settings".localized
        register()
        setContent()
        setStyle()
        AnalyticsManager.shared.recordView(.appSettings)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        save()
    }
    func setContent() {
        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl!.tintColor = UIColor.white
        tableView.refreshControl!.addTarget(self, action: #selector(pull(_:)), for: .valueChanged)
    }
    func setStyle() {
    }
    func register() {
        ["TitleCell", "AppSettingsCell", "ElectrumCell", "EditCell", "ProxyCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
    }
    @objc func pull(_ sender: UIRefreshControl? = nil) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {[weak self] in
            self?.tableView.refreshControl?.endRefreshing()
        }
    }
    override func keyboardWillShow(notification: Notification) {
        super.keyboardWillShow(notification: notification)

        guard let userInfo = notification.userInfo else { return }
        // swiftlint:disable force_cast
        var keyboardFrame: CGRect = (userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue
        keyboardFrame = self.view.convert(keyboardFrame, from: nil)
        tableView.setBottomInset(to: keyboardFrame.size.height + 40.0)
    }
    override func keyboardWillHide(notification: Notification) {
        tableView.setBottomInset(to: 0)
        super.keyboardWillHide(notification: notification)
    }
    func save() {
        let socks5 = viewModel.proxyAddress ?? ""
        if viewModel.isProxyOn && socks5.isEmpty {
            viewModel.isProxyOn = false
        }
        let newSettings = GdkSettings(
            tor: viewModel.isTorOn,
            proxy: viewModel.isProxyOn,
            socks5Hostname: String(socks5.split(separator: ":").first ?? ""),
            socks5Port: String(socks5.split(separator: ":").last ?? ""),
            personalNodeEnabled: viewModel.isElectrumOn,
            btcElectrumSrv: viewModel.serverBTC,
            liquidElectrumSrv: viewModel.serverLiquid,
            testnetElectrumSrv: viewModel.serverTestnet,
            liquidTestnetElectrumSrv: viewModel.serverLiquidtestnet,
            electrumTls: viewModel.isElectrumOn && viewModel.isTlsOn,
            gapLimit: viewModel.gapLimit
        )
        AppSettings.shared.testnet = viewModel.isTestnetOn
        AppSettings.shared.experimental = viewModel.isExperimentalOn
        AppSettings.shared.rememberHWIsOff = !viewModel.isHWOn
        AppSettings.shared.gdkSettings = newSettings
        Meld.isSandboxEnvironment = viewModel.isMeldOn

        switch AnalyticsManager.shared.consent { // current value
        case .authorized:
            if viewModel.isAnalyticsOn {
                // no change
            } else {
                AnalyticsManager.shared.consent = .denied
            }
        case .notDetermined:
            if viewModel.isAnalyticsOn {
                AnalyticsManager.shared.consent = .authorized
            } else {
//                AnalyticsManager.shared.consent = .denied
            }
        case .denied:
            if viewModel.isAnalyticsOn {
                AnalyticsManager.shared.consent = .authorized
            } else {
                // no change
            }
        }
        let session = WalletManager.current?.prominentSession?.session
        AnalyticsManager.shared.setupSession(session: session)
//        delegate?.didSet(tor: viewModel.isTorOn)
//        delegate?.didSet(testnet: viewModel.isTestnetOn)
//        navigationController?.popViewController(animated: true)
    }
    func onLanguage() {
        let storyboard = UIStoryboard(name: "Utility", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "LangSelectViewController") as? LangSelectViewController {
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: true, completion: nil)
        }
    }
    func onMeldSandbox() {}
    func onMoreInfo() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogCountlyViewController") as? DialogCountlyViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.disableControls = true
            self.present(vc, animated: false, completion: nil)
        }
    }
    func onElectrum() {
        viewModel.isElectrumOn = !viewModel.isElectrumOn
        reloadSections([.server], animated: true)
    }
    func onTor() {
        viewModel.isTorOn = !viewModel.isTorOn
    }
    func onHw() {
        viewModel.isHWOn = !viewModel.isHWOn
    }
    func onProxy() {
        viewModel.isProxyOn = !viewModel.isProxyOn
        reloadSections([.generic], animated: true)
    }
    func onTestnet() {
        viewModel.isTestnetOn = !viewModel.isTestnetOn
    }
    func onExperimental() {
        viewModel.isExperimentalOn = !viewModel.isExperimentalOn
    }
    func onAnalytics() {
        viewModel.isAnalyticsOn = !viewModel.isAnalyticsOn
    }
    func onMeld() {
        viewModel.isMeldOn = !viewModel.isMeldOn
    }
    func onTls() {
        viewModel.isTlsOn = !viewModel.isTlsOn
    }
    @MainActor
    func reloadSections(_ sections: [AppSettingsSection], animated: Bool) {
        if animated {
            tableView.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .automatic)
        } else {
            UIView.performWithoutAnimation {
                tableView.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
            }
        }
    }
}
extension AppSettingsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.sections.count
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.cellItems(viewModel.sections[section]).count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch viewModel.sections[indexPath.section] {
        case .header:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TitleCell.identifier, for: indexPath) as? TitleCell {
                cell.configure("These settings apply for every wallet you use on the Blockstream App".localized)
                cell.selectionStyle = .none
                return cell
            }
        case .generic:
            if let cell = tableView.dequeueReusableCell(withIdentifier: AppSettingsCell.identifier, for: indexPath) as? AppSettingsCell {
                let cellType: AppSettingsCellType = viewModel.cellItems(.generic)[indexPath.row]
                var onTap: (() -> Void)?
                var onHelp: (() -> Void)?
                var onActionSwitch: (() -> Void)?
                var switchState: Bool?
                switch cellType {
                case .tor:
                    switchState = viewModel.isTorOn
                    onActionSwitch = { [weak self] in self?.onTor() }
                case .proxy:
                    switchState = viewModel.isProxyOn
                    onActionSwitch = { [weak self] in self?.onProxy() }
                case .proxyEdit:
                    if let cell = tableView.dequeueReusableCell(withIdentifier: ProxyCell.identifier, for: indexPath) as? ProxyCell {
                        cell.configure(value: viewModel.proxyAddress ?? "", onChange: {[weak self] value in
                            self?.viewModel.proxyAddress = value
                        })
                        cell.selectionStyle = .none
                        return cell
                    }
                case .hw:
                    switchState = viewModel.isHWOn
                    onActionSwitch = { [weak self] in self?.onHw() }
                case .testnet:
                    switchState = viewModel.isTestnetOn
                    onActionSwitch = { [weak self] in self?.onTestnet() }
                case .help:
                    switchState = viewModel.isAnalyticsOn
                    onActionSwitch = { [weak self] in self?.onAnalytics() }
                    onHelp = { [weak self] in self?.onMoreInfo() }
                case .experimental:
                    switchState = viewModel.isExperimentalOn
                    onActionSwitch = { [weak self] in self?.onExperimental() }
                case .language:
                    switchState = nil
                    onTap = { [weak self] in self?.onLanguage() }
                case .meld:
                    switchState = viewModel.isMeldOn
                    onActionSwitch = { [weak self] in self?.onMeld() }
                default:
                    break
                }
                cell.configure(type: cellType,
                               switchState: switchState,
                               onActionSwitch: onActionSwitch,
                               onHelp: onHelp,
                               onTap: onTap)
                cell.selectionStyle = .none
                return cell
            }
        case .server:
            let cellType: AppSettingsCellType = viewModel.cellItems(.server)[indexPath.row]
            switch cellType {
            case .electrum:
                if let cell = tableView.dequeueReusableCell(withIdentifier: AppSettingsCell.identifier, for: indexPath) as? AppSettingsCell {
                    cell.configure(type: .electrum,
                                   switchState: viewModel.isElectrumOn,
                                   onActionSwitch: {[weak self] in
                        self?.onElectrum()
                    },
                                   onHelp: nil,
                                   onTap: nil)
                    cell.selectionStyle = .none
                    return cell
                }
            case .electrumEdit:
                if let cell = tableView.dequeueReusableCell(withIdentifier: ElectrumCell.identifier, for: indexPath) as? ElectrumCell {
                    cell.configure(model: viewModel.electrumCellModel,
                                   switchTlsState: viewModel.isTlsOn,
                                   onSwitchTls: {[weak self] in
                        self?.onTls()
                    },
                                   onChangeBTC: {[weak self] value in
                        self?.viewModel.serverBTC = value
                    },
                                   onChangeLiquid: {[weak self] value in
                        self?.viewModel.serverLiquid = value
                    },
                                   onChangeTestnet: {[weak self] value in
                        self?.viewModel.serverTestnet = value
                    },
                                   onChangeLiquidTestnet: {[weak self] value in
                        self?.viewModel.serverLiquidtestnet = value
                    }
                    )
                    cell.selectionStyle = .none
                    return cell
                }
            default:
                break
            }
        case .limit:
            let cellType: AppSettingsCellType = viewModel.cellItems(.limit)[indexPath.row]
            switch cellType {
            case .addresses:
                if let cell = tableView.dequeueReusableCell(withIdentifier: EditCell.identifier, for: indexPath) as? EditCell {
                    cell.configure(number: viewModel.gapLimit,
                                   onChange: {[weak self] value in
                        self?.viewModel.gapLimit = value
                    })
                    cell.selectionStyle = .none
                    return cell
                }
            default:
                break
            }
        }
        return UITableViewCell()
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch viewModel.sections[section] {
        case .header, .generic:
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
        case .header, .generic:
            return nil
        case .server:
            return sectionHeader("id_custom_server_settings".localized)
        case .limit:
            return sectionHeader("id_electrum_server_gap_limit".localized)
        }
    }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch viewModel.sections[indexPath.section] {
        case .header, .generic, .server, .limit:
            return
        }
    }
}
extension AppSettingsViewController {
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
