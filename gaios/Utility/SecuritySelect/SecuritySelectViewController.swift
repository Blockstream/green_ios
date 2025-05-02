import UIKit
import core
import gdk

enum SecuritySelectSection: Int, CaseIterable {
    case asset
    case policy
    case footer
}

protocol SecuritySelectViewControllerDelegate: AnyObject {
    func didCreatedWallet(_ wallet: WalletItem)
}

class SecuritySelectViewController: UIViewController {

    enum FooterType {
        case noTransactions
        case none
    }

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var btnAdvanced: UIButton!

    private var headerH: CGFloat = 54.0
    private var footerH: CGFloat = 54.0

    var viewModel: SecuritySelectViewModel!
    weak var delegate: SecuritySelectViewControllerDelegate?
    var visibilityState: Bool = false
    var dialogJadeCheckViewController: DialogJadeCheckViewController?
    var walletCreated: WalletItem?
    var credentialsCreated: Credentials?

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.unarchiveCreateDialog = unarchiveCreateDialog

        ["PolicyCell", "AssetSelectCell" ].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }

        setContent()
        setStyle()

        let account = AccountsRepository.shared.current
        AnalyticsManager.shared.recordView(.addAccountChooseType, sgmt: AnalyticsManager.shared.sessSgmt(account))
    }

    func unarchiveCreateDialog(completion: @escaping (Bool) -> ()) {
        let alert = UIAlertController(title: "id_archived_account".localized,
                                          message: "id_there_is_already_an_archived".localized,
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "id_unarchive_account".localized,
                                          style: .cancel) { (_: UIAlertAction) in
                completion(false)
            })
            alert.addAction(UIAlertAction(title: "id_create".localized,
                                          style: .default) { (_: UIAlertAction) in
                completion(true)
            })
            DispatchQueue.main.async {
                self.present(alert, animated: true, completion: nil)
            }
    }

    @MainActor
    func reloadSections(_ sections: [SecuritySelectSection], animated: Bool) {
        if animated {
            tableView.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
        } else {
            UIView.performWithoutAnimation {
                tableView.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
            }
        }
    }

    func setContent() {
        title = "id_create_new_account".localized
        btnAdvanced.setTitle( visibilityState ? "id_hide_advanced_options".localized : "id_show_advanced_options".localized, for: .normal)
    }

    func setStyle() {
    }

    @IBAction func btnAdvanced(_ sender: Any) {
        viewModel?.showAll.toggle()
        reloadSections([.policy], animated: true)
        visibilityState = !visibilityState
        setContent()
    }
}

extension SecuritySelectViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return SecuritySelectSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        switch SecuritySelectSection(rawValue: section) {
        case .asset:
            return 1
        case .policy:
            return viewModel?.getPolicyCellModels().count ?? 0
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        btnAdvanced.isHidden = !viewModel.isAdvancedEnable()

        switch SecuritySelectSection(rawValue: indexPath.section) {
        case .asset:
            if let cell = tableView.dequeueReusableCell(withIdentifier: AssetSelectCell.identifier, for: indexPath) as? AssetSelectCell,
               let model = viewModel?.assetCellModel {
                cell.configure(model: model, showEditIcon: true)
                cell.selectionStyle = .none
                return cell
            }
        case .policy:
            if let cell = tableView.dequeueReusableCell(withIdentifier: PolicyCell.identifier, for: indexPath) as? PolicyCell,
               let model = viewModel {
                cell.configure(model: model.getPolicyCellModels()[indexPath.row], hasLightning: viewModel.hasLightning())
                cell.selectionStyle = .none
                return cell
            }
        default:
            break
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch SecuritySelectSection(rawValue: section) {
        default:
            return headerH
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch SecuritySelectSection(rawValue: section) {
        case .footer:
            return 100.0
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {

        switch SecuritySelectSection(rawValue: indexPath.section) {
        default:
            return UITableView.automaticDimension
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {

        switch SecuritySelectSection(rawValue: section) {
        case .asset:
            return headerView( "id_asset".localized )
        case .policy:
            return headerView("id_choose_security_policy".localized )
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        switch SecuritySelectSection(rawValue: section) {
        default:
            return footerView(.none)
        }
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch SecuritySelectSection(rawValue: indexPath.section) {
        default:
            return indexPath
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        switch SecuritySelectSection(rawValue: indexPath.section) {
        case .asset:
            let storyboard = UIStoryboard(name: "Utility", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "AssetSelectViewController") as? AssetSelectViewController {
                let allAssets = WalletManager.current?.registry.all
                let assetInfos = viewModel.onlyBtc ? [AssetInfo.btc] : allAssets
                let assetIds = assetInfos?.map { ($0.assetId, Int64(0)) }
                let dict = Dictionary(uniqueKeysWithValues: assetIds ?? [])
                let list = AssetAmountList(dict)
                
                // TODO: handle amp case
                vc.viewModel = AssetSelectViewModel(assets: list,
                                                    enableAnyLiquidAsset: viewModel.onlyBtc ? false : true,
                                                    enableAnyAmpAsset: viewModel.onlyBtc ? false : true)
                vc.delegate = self
                navigationController?.pushViewController(vc, animated: true)
            }
        case .policy:
            let policy = viewModel.getPolicyCellModels()[indexPath.row].policy
            if policy == .TwoOfThreeWith2FA {
                let storyboard = UIStoryboard(name: "Accounts", bundle: nil)
                if let vc = storyboard.instantiateViewController(withIdentifier: "AccountCreateRecoveryKeyViewController") as? AccountCreateRecoveryKeyViewController {
                    if let network = policy.getNetwork(testnet: WalletManager.current?.testnet ?? false,
                                                       liquid: viewModel.asset != "btc"),
                       let session = viewModel.getSession(for: network) {
                        vc.session = session
                        vc.delegate = self
                        navigationController?.pushViewController(vc, animated: true)
                    }
                }
            } else {
                accountCreate(policy)
            }
        default:
            break
        }
    }

    func accountCreate(_ policy: PolicyCellType) {
        // Derive key from jade for lightning wallet
        if AccountsRepository.shared.current?.isJade ?? false && policy == .Lightning {
            if WalletManager.current?.lightningSession?.logged ?? false {
                self.showError("You already have a lightning account. Only one per wallet can be created".localized)
                return
            }
            ltExportJadeViewController()
            return
        }
        // For not jade wallet
        startLoader(message: String(format: "id_creating_your_s_account".localized, policy.accountType.shortString))
        Task {
            do {
                let wallet = try await viewModel.create(policy: policy, params: nil)
                self.stopLoader()
                if let wallet = wallet {
                    self.didCreatedWallet(wallet)
                }
            } catch {
                self.stopLoader()
                self.showError(error)
            }
        }
    }

    @MainActor
    func showHWCheckDialog() {
        let storyboard = UIStoryboard(name: "Shared", bundle: nil)
        dialogJadeCheckViewController = storyboard.instantiateViewController(withIdentifier: "DialogJadeCheckViewController") as? DialogJadeCheckViewController
        if let vc = dialogJadeCheckViewController {
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @MainActor
    func ltExportJadeViewController() {
        let storyboard = UIStoryboard(name: "LTFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "LTExportJadeViewController") as? LTExportJadeViewController {
            vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    @MainActor
    func hideHWCheckDialog() {
        dialogJadeCheckViewController?.dismiss()
    }

    func createSubaccount(policy: PolicyCellType, params: CreateSubaccountParams?) {
        let isHW = AccountsRepository.shared.current?.isHW ?? false
        if isHW {
            showHWCheckDialog()
        } else {
            startLoader(message: String(format: "id_creating_your_s_account".localized, policy.accountType.shortString))
        }
        Task {
            do {
                let wallet = try await viewModel.create(policy: policy, params: params)
                await MainActor.run {
                    self.stopLoader()
                    DropAlert().success(message: "id_new_account_created".localized)
                    navigationController?.popToRootViewController(animated: true)
                    if let wallet = wallet {
                        delegate?.didCreatedWallet(wallet)
                    }
                }
            } catch {
                self.showError(error)
            }
            self.stopLoader()
            if isHW {
                hideHWCheckDialog()
            }
        }
    }
}

extension SecuritySelectViewController: LTExportJadeViewControllerDelegate {
    func didExportedWallet(credentials: gdk.Credentials, wallet: gdk.WalletItem) {
        didCreatedWallet(wallet, credentials: credentials)
    }
}

extension SecuritySelectViewController {

    func headerView(_ txt: String) -> UIView {

        let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: headerH))
        section.backgroundColor = UIColor.clear
        let title = UILabel(frame: .zero)
        title.font = .systemFont(ofSize: 14.0, weight: .semibold)
        title.text = txt
        title.textColor = .white.withAlphaComponent(0.6)
        title.numberOfLines = 1

        title.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(title)

        NSLayoutConstraint.activate([
            title.centerYAnchor.constraint(equalTo: section.centerYAnchor, constant: 10.0),
            title.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 30),
            title.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: 30)
        ])

        return section
    }

    func footerView(_ type: FooterType) -> UIView {

        switch type {
        default:
            let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 1.0))
            section.backgroundColor = .clear
            return section
        }
    }
}

extension SecuritySelectViewController: AssetSelectViewControllerDelegate {
    func didSelectAsset(_ assetId: String) {
        viewModel?.resetSelection()
        viewModel?.asset = assetId
        reloadSections([.asset, .policy], animated: true)
        navigationController?.popViewController(animated: true)
    }

    func didSelectAnyAsset(_ type: AnyAssetType) {
        // handle any asset case
        viewModel?.resetSelection()
        switch type {
        case .liquid:
            viewModel?.anyLiquidAsset = true
            reloadSections([.asset, .policy], animated: true)
        case .amp:
            viewModel?.anyLiquidAmpAsset = true
            reloadSections([.asset, .policy], animated: true)
        }
        navigationController?.popViewController(animated: true)
    }

    @MainActor
    func didCreatedWallet(_ wallet: WalletItem, credentials: Credentials? = nil) {
        walletCreated = wallet
        credentialsCreated = credentials

        // for not lightning subaccount creation: exit
        if !wallet.isLightning {
            DropAlert().success(message: "id_new_account_created".localized)
            self.navigationController?.popViewController(animated: true)
            self.delegate?.didCreatedWallet(wallet)
            return
        }

        // only for lightning subaccount creation: add lightning shortcut
        let account = WalletManager.current?.account
        if let account = account, !account.isEphemeral && !(account.hidden ?? false) {
            Task {
                startLoader(message: "")
                do {
                    if let credentials = credentialsCreated {
                        try await viewModel.addHWShortcutLightning(credentials)
                    } else {
                        try await viewModel.addSWShortcutLightning()
                    }
                    self.stopLoader()
                    self.navigationController?.popViewController(animated: true)
                    self.delegate?.didCreatedWallet(wallet)
                } catch {
                    self.stopLoader()
                    self.showError(error)
                }
            }
        }
    }
}

extension SecuritySelectViewController: AccountCreateRecoveryKeyDelegate {
    func didPublicKey(_ key: String) {
        let cellModel = PolicyCellModel.from(policy: .TwoOfThreeWith2FA)
        let name = viewModel.uniqueName(cellModel.policy.accountType, liquid: viewModel.asset != "btc")
        let params = CreateSubaccountParams(name: name,
                                            type: .twoOfThree,
                                            recoveryMnemonic: nil,
                                            recoveryXpub: key)
        createSubaccount(policy: .TwoOfThreeWith2FA, params: params)
    }

    func didNewRecoveryPhrase(_ mnemonic: String) {
        let cellModel = PolicyCellModel.from(policy: .TwoOfThreeWith2FA)
        let name = viewModel.uniqueName(cellModel.policy.accountType, liquid: viewModel.asset != "btc")
        let params = CreateSubaccountParams(name: name,
                                            type: .twoOfThree,
                                            recoveryMnemonic: mnemonic,
                                            recoveryXpub: nil)
        createSubaccount(policy: .TwoOfThreeWith2FA, params: params)
    }

    func didExistingRecoveryPhrase(_ mnemonic: String) {
        let cellModel = PolicyCellModel.from(policy: .TwoOfThreeWith2FA)
        let name = viewModel.uniqueName(cellModel.policy.accountType, liquid: viewModel.asset != "btc")
        let params = CreateSubaccountParams(name: name,
                                            type: .twoOfThree,
                                            recoveryMnemonic: mnemonic,
                                            recoveryXpub: nil)
        createSubaccount(policy: .TwoOfThreeWith2FA, params: params)
    }
}
