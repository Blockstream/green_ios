import UIKit
import hw
import core

class TabSecurityVC: TabViewController {

    @IBOutlet weak var tableView: UITableView!
    private var completion: (() -> Void)?

    var backupCardCellModel = [AlertCardCellModel]()
    var unlockCellModel: [PreferenceCellModel] {
        var list = [PreferenceCellModel]()
        let hasBiometricUnlock = walletModel.wm?.account.hasBioPin == true || walletModel.wm?.account.hasWoCredentials == true
        let hasManualPin = walletModel.wm?.account.hasManualPin == true
        let isWatchonly = walletModel.wm?.isWatchonly ?? false
        if !isWatchonly {
            list.append(PreferenceCellModel(preferenceType: .bio, state: hasBiometricUnlock ? .on : .off))
            list.append(PreferenceCellModel(preferenceType: .pin, state: hasManualPin ? .on : .off))
        }
        return list
    }
    var jadeCellModel: [PreferenceCellModel] {
        let isHW = walletModel.wm?.account.isJade ?? false
        if !isHW {
            return []
        }
        let boardType = WalletManager.current?.account.boardType ?? BleHwManager.shared.jade?.version?.boardType
        switch boardType {
        case .some(.v2):
            return [
                PreferenceCellModel(preferenceType: .genuineCheck, state: .unknown),
                PreferenceCellModel(preferenceType: .fwUpdate, state: .unknown)]
        default:
            return [PreferenceCellModel(preferenceType: .fwUpdate, state: .unknown)]
        }
    }
    var recoveryCellModel: [PreferenceCellModel] {
        let isWatchonly = walletModel.wm?.isWatchonly ?? false
        let isHW = walletModel.wm?.isHW ?? false
        if !isWatchonly && !isHW {
            return [PreferenceCellModel(preferenceType: .recoveryPhrase, state: .unknown)]
        }
        return []
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.gBlackBg()

        register()
        setContent()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadAlertCards()
        tableView.reloadData()
    }
    func setContent() {
        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl!.tintColor = UIColor.white
        tableView.refreshControl!.addTarget(self, action: #selector(pull(_:)), for: .valueChanged)
    }

    func register() {
        ["TabHeaderCell", "SecurityLevelCell", "PreferenceCell", "AlertCardCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
    }
    @objc func pull(_ sender: UIRefreshControl? = nil) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {[weak self] in
            self?.tableView.refreshControl?.endRefreshing()
        }
    }
    @MainActor
    func reloadSections(_ sections: [TabHomeSection], animated: Bool) {
        if animated {
            tableView?.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
        } else {
            UIView.performWithoutAnimation {
                tableView?.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
            }
        }
    }
    func reloadAlertCards() {
        var cards: [AlertCardType] = []
        if BackupHelper.shared.needsBackup(walletId: walletModel.wm?.account.id) && BackupHelper.shared.isDismissed(walletId: walletModel.wm?.account.id, position: .securityTab) == false {
            cards.append(.backup)
        }
        self.backupCardCellModel = cards.map { AlertCardCellModel(type: $0) }
    }
    func onCompare() {
        securityCompareScreen()
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
            if walletModel.wm?.account.isHW ?? false {
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
                navigationController?.pushViewController(vc, animated: true)
            }
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
                DropAlert().error(message: "Firmware update failed")
            }
        case .failure(let err):
            switch err as? HWError {
            case .some(HWError.NoNewFirmwareFound):
                DropAlert().success(message: "Firmware up to date")
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
        return TabSecuritySection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        switch TabSecuritySection(rawValue: section) {
        case .header:
            return 1
        case .level:
            return 1
        case .jade:
            return walletModel.wm?.account.isJade ?? false ? jadeCellModel.count : 0
        case .backup:
            return backupCardCellModel.count
        case .unlock:
            return unlockCellModel.count
        case .recovery:
            return recoveryCellModel.count
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        switch TabSecuritySection(rawValue: indexPath.section) {

        case .header:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TabHeaderCell.identifier, for: indexPath) as? TabHeaderCell {
                cell.configure(title: "Security".localized, icon: walletModel.headerIcon, tab: .security, onTap: {[weak self] in
                    self?.walletTab.switchNetwork()
                })
                cell.selectionStyle = .none
                return cell
            }
        case .level:
            if let cell = tableView.dequeueReusableCell(withIdentifier: SecurityLevelCell.identifier, for: indexPath) as? SecurityLevelCell {
                cell.configure(isHW: walletModel.wm?.account.isHW == true, onCompare: {[weak self] in
                    self?.onCompare()
                })
                cell.selectionStyle = .none
                return cell
            }
        case .jade:
            if let cell = tableView.dequeueReusableCell(withIdentifier: PreferenceCell.identifier, for: indexPath) as? PreferenceCell {
                let model = jadeCellModel[indexPath.row]
                cell.configure(model: model,
                               onTap: {[weak self] in
                    self?.onPreferenceCell(model)
                })
                cell.selectionStyle = .none
                return cell
            }
        case .backup:
            if let cell = tableView.dequeueReusableCell(withIdentifier: "AlertCardCell", for: indexPath) as? AlertCardCell {
                let alertCard = backupCardCellModel[indexPath.row]
                switch alertCard.type {
                case .backup:
                    cell.configure(alertCard,
                                   onLeft: {[weak self] in
                        if let vc = AccountNavigator.recover() {
                            self?.navigationController?.pushViewController(vc, animated: true)
                        }
                    },
                                   onRight: nil,
                                   onDismiss: nil)
                default:
                    break
                }
                cell.selectionStyle = .none
                return cell
            }
        case .unlock:
            if let cell = tableView.dequeueReusableCell(withIdentifier: PreferenceCell.identifier, for: indexPath) as? PreferenceCell {
                let model = unlockCellModel[indexPath.row]
                cell.configure(model: model,
                               onTap: {[weak self] in
                    self?.onPreferenceCell(model)
                })
                cell.selectionStyle = .none
                return cell
            }
        case .recovery:
            if let cell = tableView.dequeueReusableCell(withIdentifier: PreferenceCell.identifier, for: indexPath) as? PreferenceCell {
                let model = recoveryCellModel[indexPath.row]
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
        switch TabSecuritySection(rawValue: section) {
        case .jade:
            return jadeCellModel.count > 0 ? sectionHeaderH : 0.1
        case .unlock:
            return unlockCellModel.count > 0 ? sectionHeaderH : 0.1
        case .recovery:
            return recoveryCellModel.count > 0 ? sectionHeaderH : 0.1
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch TabSecuritySection(rawValue: section) {
        case .header:
            return 0.1
            // return headerH
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch TabSecuritySection(rawValue: indexPath.section) {
        default:
            return UITableView.automaticDimension
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {

        switch TabSecuritySection(rawValue: section) {
        case .jade:
            return jadeCellModel.count > 0 ? sectionHeader("Your Jade".localized) : nil
        case .unlock:
            return unlockCellModel.count > 0 ? sectionHeader("View Balance".localized) : nil
        case .recovery:
            return recoveryCellModel.count > 0 ? sectionHeader("Recovery method".localized) : nil
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        switch TabSecuritySection(rawValue: section) {
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch TabSecuritySection(rawValue: indexPath.section) {
        default:
            return nil // indexPath
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch TabSecuritySection(rawValue: indexPath.section) {
        default:
            break
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
