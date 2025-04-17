import UIKit

class TabSecurityVC: TabViewController {

    @IBOutlet weak var tableView: UITableView!

    var backupCardCellModel = [AlertCardCellModel]()
    var unlockCellModel: [PreferenceCellModel] {
        [PreferenceCellModel(preferenceType: .faceID, state: walletModel.wm?.account.hasBioPin == true ? .on : .off),
         PreferenceCellModel(preferenceType: .pin, state: walletModel.wm?.account.hasPin == true ? .on : .off)]
    }
    var jadeCellModel: [PreferenceCellModel] {
        [PreferenceCellModel(preferenceType: .genuineCheck, state: .unknown),
         PreferenceCellModel(preferenceType: .fwUpdate, state: .unknown)]
    }
    var recoveryCellModel: [PreferenceCellModel] {
        [PreferenceCellModel(preferenceType: .recoveryPhrase, state: .unknown)]
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.gBlackBg()

        register()
        setContent()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

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
    func onPreferenceCell(_ type: PreferenceType) {
        switch type {
        case .faceID:
            break
        case .pin:
            break
        case .genuineCheck:
            break
        case .fwUpdate:
            break
        case .recoveryPhrase:
            let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "ManualBackupViewController") as? ManualBackupViewController {
                navigationController?.pushViewController(vc, animated: true)
            }
        }
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
            return walletModel.wm?.account.isJade ?? false ? 2 : 0
        case .backup:
            return backupCardCellModel.count
        case .unlock:
            return 2
        case .recovery:
            return walletModel.canShowMnemonic() ? 1 : 0
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        switch TabSecuritySection(rawValue: indexPath.section) {

        case .header:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TabHeaderCell.identifier, for: indexPath) as? TabHeaderCell {
                cell.configure(title: "Security".localized, icon: walletModel.headerIcon, onTap: {[weak self] in
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
                    self?.onPreferenceCell(model.type)
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
                        let storyboard = UIStoryboard(name: "Recovery", bundle: nil)
                        if let vc = storyboard.instantiateViewController(withIdentifier: "RecoveryCreateViewController") as? RecoveryCreateViewController {
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
                    self?.onPreferenceCell(model.type)
                })
                cell.selectionStyle = .none
                return cell
            }
        case .recovery:
            if let cell = tableView.dequeueReusableCell(withIdentifier: PreferenceCell.identifier, for: indexPath) as? PreferenceCell {
                let model = recoveryCellModel[indexPath.row]
                cell.configure(model: model,
                               onTap: {[weak self] in
                    self?.onPreferenceCell(model.type)
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
            if walletModel.wm?.account.isJade ?? false {
                return sectionHeaderH
            } else { return 0.1 }
        case .unlock:
            return sectionHeaderH
        case .recovery:
            if walletModel.canShowMnemonic() {
                return sectionHeaderH
            } else { return 0.1 }
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
            if walletModel.wm?.account.isJade ?? false {
                return sectionHeader("Your Jade".localized)
            } else { return nil }
        case .unlock:
            return sectionHeader("Unlock method".localized)
        case .recovery:
            if walletModel.canShowMnemonic() {
                return sectionHeader("Recovery method".localized)
            } else { return nil }
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
