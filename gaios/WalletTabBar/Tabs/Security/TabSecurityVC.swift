import UIKit
import hw
import core

class TabSecurityVC: TabViewController {

    @IBOutlet weak var tableView: UITableView!
    private var completion: (() -> Void)?
    let viewModel: TabSecurityVM

    init?(coder: NSCoder, viewModel: TabSecurityVM) {
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
        viewModel.onUpdate = { [weak self] feature in
            DispatchQueue.main.async {
                self?.onUpdate(feature: feature)
            }
        }
        viewModel.refresh(features: [.security])
    }
    func onUpdate(feature: RefreshFeature?) {
        switch feature {
        case .security:
            if tableView?.refreshControl?.isRefreshing == true {
                tableView?.refreshControl?.endRefreshing()
            }
            tableView?.reloadData()
        default:
            break
        }
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.refresh(features: [.security])
    }
    func setContent() {
        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl!.tintColor = UIColor.white
        tableView.refreshControl!.addTarget(self, action: #selector(pull(_:)), for: .valueChanged)
    }

    func register() {
        ["TabHeaderCell", "SecurityLevelCell", "PreferenceCell", "AlertCardCell", "WatchonlyCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
    }
    @objc func pull(_ sender: UIRefreshControl? = nil) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {[weak self] in
            self?.tableView.refreshControl?.endRefreshing()
        }
    }
    func onCompare() {
        securityCompareScreen()
    }
    func onLearnMore() {
        SafeNavigationManager.shared.navigate( ExternalUrls.learnMoreWatchonly )
    }
    func editProtection(type: EditProtectionType, action: EditProtectionAction) {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "EditProtectionViewController") as? EditProtectionViewController {
            vc.protectionType = type
            vc.protectionAction = action
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func onPreferenceCell(_ model: PreferenceCellModel) {
        switch model.type {
        case .bio:
            if viewModel.mainAccount.isHW {
                DropAlert().error(message: "Toggle is not supported with Hardware Wallet")
            } else {
                editProtection(type: model.hasTouchID ? .touchID : .faceID, action: model.state == .on ? .disable : .enable)
            }
        case .pin:
            editProtection(type: .pin, action: model.state == .on ? .change : .enable)
        case .genuineCheck:
            onGenuineCheck()
        case .fwUpdate:
            onFwUpdate()
        case .recoveryPhrase:
            let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "ManualBackupViewController") as? ManualBackupViewController {
                vc.viewModel = ManualBackupViewModel(.phrase)
                navigationController?.pushViewController(vc, animated: true)
            }
        case .header:
            return
        }
    }
    func onGenuineCheck() {
        completion = { [weak self] in
            Task { [weak self] in
                self?.startLoader()
                let version = try? await BleHwManager.shared.jade?.version()
                self?.stopLoader()
                if version?.boardType == .v2 {
                    self?.presentGenuineCheckEndViewController()
                } else {
                    DropAlert().error(message: "Genuine check not available")
                }
            }
        }
        presentConnectViewController(authentication: false)
    }
    func onFwUpdate() {
        completion = {
            Task { [weak self] in
                self?.startLoader()
                await self?.checkFirmware()
                self?.stopLoader()
            }
        }
        presentConnectViewController(authentication: false)
    }
    func checkFirmware() async {
        let task = Task.detached {
            try await BleHwManager.shared.checkFirmware()
        }
        switch await task.result {
        case .success(let res):
            if let version = res.0, let lastFirmware = res.1 {
                presentUpdateFirmwareViewController(version: version, lastFirmware: lastFirmware)
            } else {
                DropAlert().error(message: "id_firmware_update_failed".localized)
            }
        case .failure(let err):
            switch err as? HWError {
            case .some(HWError.NoNewFirmwareFound):
                DropAlert().success(message: "id_firmware_up_to_date".localized)
            default:
                DropAlert().error(message: err.description().localized)
            }
        }
    }

    @MainActor
    func presentGenuineCheckEndViewController() {
        let storyboard = UIStoryboard(name: "GenuineCheckFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "GenuineCheckEndViewController") as? GenuineCheckEndViewController {
            vc.delegate = self
            vc.model = GenuineCheckEndViewModel(BleHwManager: BleHwManager.shared)
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: true)
        }
    }

    @MainActor
    func presentConnectViewController(authentication: Bool) {
        let storyboard = UIStoryboard(name: "HWDialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "HWDialogConnectViewController") as? HWDialogConnectViewController {
            vc.delegate = self
            vc.authentication = authentication
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @MainActor
    func presentUpdateFirmwareViewController(version: JadeVersionInfo, lastFirmware: Firmware) {
        let storyboard = UIStoryboard(name: "HWFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "UpdateFirmwareViewController") as? UpdateFirmwareViewController {
            vc.firmware = lastFirmware
            vc.version = version.jadeVersion
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }

    @MainActor
    func presentDialogErrorViewController(error: Error) {
        let request = ZendeskErrorRequest(
            error: error.description().localized,
            network: .bitcoinSS,
            shareLogs: true,
            screenName: "FailedGenuineCheck")
        presentContactUsViewController(request: request)
    }
}

extension TabSecurityVC: UpdateFirmwareViewControllerDelegate {
    func didUpdate(version: String, firmware: Firmware) {
        completion = {
            Task { [weak self] in
                await self?.upgrade(version: version, firmware: firmware)
            }
        }
        presentConnectViewController(authentication: true)
    }
    func upgrade(version: String, firmware: Firmware) async {
        let task = Task.detached { [weak self] in
            await self?.startLoader(message: "id_fetching_new_firmware".localized)
            let binary = try await BleHwManager.shared.fetchFirmware(firmware: firmware)
            let hash = BleHwManager.shared.jade?.jade.sha256(binary)
            let hashHex = hash?.hex.separated(by: " ", every: 8)
            await self?.startLoader(message: "id_updating_firmware".localized + "\n\n\(hashHex ?? "")")
            let res = try await BleHwManager.shared.updateFirmware(firmware: firmware, binary: binary)
            try await BleHwManager.shared.disconnect()
            try await Task.sleep(nanoseconds: 5 * 1_000_000_000)
            return res
        }
        switch await task.result {
        case .success(let updated):
            stopLoader()
            if updated {
                DropAlert().success(message: "id_firmware_update_completed".localized)
            } else {
                DropAlert().error(message: "id_operation_failure".localized)
            }
        case .failure(let err):
            stopLoader()
            showError(err.description().localized)
        }
    }

    func didSkip() {
        print("Jade update skip")
    }
}
extension TabSecurityVC: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.security.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.security[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch viewModel.security[indexPath.section].section {
        case .header:
            let headerIcon = UIImage(named: viewModel.mainAccount.gdkNetwork.mainnet ? "ic_wallet" : "ic_wallet_testnet")?.maskWithColor(color: .white)
            if let cell = tableView.dequeueReusableCell(withIdentifier: TabHeaderCell.identifier, for: indexPath) as? TabHeaderCell, let headerIcon {
                cell.configure(title: "id_security".localized, icon: headerIcon, tab: .security, onTap: {[weak self] in
                    self?.walletTab.switchNetwork()
                })
                cell.selectionStyle = .none
                return cell
            }
        case .level:
            if let cell = tableView.dequeueReusableCell(withIdentifier: SecurityLevelCell.identifier, for: indexPath) as? SecurityLevelCell {
                cell.configure(isHW: viewModel.mainAccount.isHW == true, onCompare: {[weak self] in
                    self?.onCompare()
                })
                cell.selectionStyle = .none
                return cell
            }
        case .watchonly:
            if let cell = tableView.dequeueReusableCell(withIdentifier: WatchonlyCell.identifier, for: indexPath) as? WatchonlyCell {
                cell.configure(onLearnMore: {[weak self] in
                    self?.onLearnMore()
                })
                cell.selectionStyle = .none
                return cell
            }
        case .jade:
            if let cell = tableView.dequeueReusableCell(withIdentifier: PreferenceCell.identifier, for: indexPath) as? PreferenceCell {
                let type = viewModel.security[indexPath.section].items[indexPath.row]
                let model = PreferenceCellModel(preferenceType: type, state: .unknown)
                cell.configure(model: model,
                               onTap: {[weak self] in
                    self?.onPreferenceCell(model)
                })
                cell.selectionStyle = .none
                return cell
            }
        case .backup:
            if let cell = tableView.dequeueReusableCell(withIdentifier: "AlertCardCell", for: indexPath) as? AlertCardCell {
                if let backup = viewModel.backupCards.first {
                    let alertCard = AlertCardCellModel(type: backup)
                    cell.configure(
                        alertCard,
                        onLeft: {[weak self] in
                            if let vc = AccountNavigator.backupIntro(.quiz) {
                                self?.navigationController?.pushViewController(vc, animated: true)
                            }
                        },
                        onRight: nil,
                        onDismiss: {
                            BackupHelper.shared.addToDismissed(walletId: self.viewModel.mainAccount.id, position: .securityTab)
                            tableView.reloadData()
                        })
                    cell.selectionStyle = .none
                    return cell
                }
            }
        case .unlock:
            if let cell = tableView.dequeueReusableCell(withIdentifier: PreferenceCell.identifier, for: indexPath) as? PreferenceCell {
                let type = viewModel.security[indexPath.section].items[indexPath.row]
                switch type {
                case .bio:
                    let hasBiometricUnlock = viewModel.mainAccount.hasBioPin || viewModel.mainAccount.hasWoBioCredentials
                    let bio = PreferenceCellModel(preferenceType: .bio, state: hasBiometricUnlock ? .on : .off)
                    cell.configure(model: bio, onTap: {[weak self] in self?.onPreferenceCell(bio) })
                case .pin:
                    let hasManualPin = viewModel.mainAccount.hasManualPin
                    let pin = PreferenceCellModel(preferenceType: .pin, state: hasManualPin ? .on : .off)
                    cell.configure(model: pin, onTap: {[weak self] in self?.onPreferenceCell(pin) })
                default:
                    break
                }
                cell.selectionStyle = .none
                return cell
            }
        case .recovery:
            if let cell = tableView.dequeueReusableCell(withIdentifier: PreferenceCell.identifier, for: indexPath) as? PreferenceCell {
                let model = PreferenceCellModel(preferenceType: .recoveryPhrase, state: .unknown)
                cell.configure(model: model,
                               onTap: {[weak self] in
                    self?.onPreferenceCell(model)
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
        viewModel.security[section].items.count > 0 ? sectionHeaderH : 0.1
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.1
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let section = viewModel.security[section]
        switch section.section {
        case .jade:
            return section.items.count > 0 ? sectionHeader("id_your_jade".localized) : nil
        case .unlock:
            return section.items.count > 0 ? sectionHeader("id_unlock_method".localized) : nil
        case .recovery:
            return section.items.count > 0 ? sectionHeader("id_recovery_method".localized) : nil
        default:
            return nil
        }
    }
}
extension TabSecurityVC {
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

extension TabSecurityVC: HWDialogConnectViewControllerDelegate {
    func connected() {
        completion?()
    }

    func logged() {
        completion?()
    }

    func cancel() {
        // nothing
    }

    func failure(err: Error) {
        showError(err)
    }
}

extension TabSecurityVC: GenuineCheckEndViewControllerDelegate {
    func onTap(_ action: GenuineCheckEndAction) {
        switch action {
        case .cancel, .continue, .diy:
            tableView.reloadData()
        case .retry:
            presentGenuineCheckEndViewController()
        case .support:
            presentDialogErrorViewController(error: HWError.Abort(""))
        case .error(let err):
            let message = err?.description().localized
            showError(message ?? "id_operation_failure".localized)
        }
    }
}
