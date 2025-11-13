import UIKit
import core
import gdk

enum SecuritySelectSection: Int, CaseIterable {
    case asset
    case policy
    case footer
}

protocol SecuritySelectViewControllerDelegate: AnyObject {
    func didCreateWallet()
    func didUnarchiveWallet()
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

    func unarchiveCreateDialog(completion: @escaping (Bool) -> Void) {
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
        btnAdvanced.setStyle(.inline)
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
            return headerView("id_security_policy".localized )
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
                vc.viewModel = AssetSelectViewModel(assets: list,
                                                    enableAnyLiquidAsset: viewModel.onlyBtc ? false : true,
                                                    enableAnyAmpAsset: false)
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
                let isLiquid = viewModel.anyLiquidAsset || viewModel.anyLiquidAmpAsset || viewModel.asset != "btc"
                let params = CreateSubaccountParams(
                    name: viewModel.uniqueName(policy.accountType, liquid: isLiquid),
                    type: policy.accountType,
                    recoveryMnemonic: nil,
                    recoveryXpub: nil)
                Task { await createSubaccount(policy: policy, params: params) }
            }
        default:
            break
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
    func hideHWCheckDialog() {
        dialogJadeCheckViewController?.dismiss()
    }

    @MainActor
    func createSubaccount(policy: PolicyCellType, params: CreateSubaccountParams) async {
        let isHW = AccountsRepository.shared.current?.isHW ?? false
        if isHW {
            showHWCheckDialog()
        } else {
            startLoader(message: String(format: "id_creating_your_s_account".localized, policy.accountType.shortString))
        }
        let task = Task { try await viewModel.create(policy: policy, params: params) }
        switch await task.result {
        case .success(let action):
            self.stopLoader()
            if isHW {
                self.hideHWCheckDialog()
            }
            switch action {
            case .created:
                self.didCreateWallet()
            case .unarchived:
                self.didUnarchiveWallet()
            }
            navigationController?.popToRootViewController(animated: true)
        case .failure(let error):
            self.stopLoader()
            if isHW {
                self.hideHWCheckDialog()
            }
            self.showError(error)
        }
    }
}

extension SecuritySelectViewController {

    func headerView(_ txt: String) -> UIView {

        let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: headerH))
        section.backgroundColor = UIColor.clear
        let title = UILabel(frame: .zero)
        title.setStyle(.txtSectionHeader)
        title.text = txt
        title.textColor = UIColor.gGrayTxt()
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
        // navigationController?.popViewController(animated: true)
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
        // navigationController?.popViewController(animated: true)
    }

    @MainActor
    func didCreateWallet() {
        DropAlert().success(message: "id_new_account_created".localized)
        delegate?.didCreateWallet()
    }
    @MainActor
    func didUnarchiveWallet() {
        DropAlert().success(message: "Account unarchived".localized)
        delegate?.didUnarchiveWallet()
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
        Task { await createSubaccount(policy: .TwoOfThreeWith2FA, params: params) }
    }

    func didNewRecoveryPhrase(_ mnemonic: String) {
        let cellModel = PolicyCellModel.from(policy: .TwoOfThreeWith2FA)
        let name = viewModel.uniqueName(cellModel.policy.accountType, liquid: viewModel.asset != "btc")
        let params = CreateSubaccountParams(name: name,
                                            type: .twoOfThree,
                                            recoveryMnemonic: mnemonic,
                                            recoveryXpub: nil)
        Task { await createSubaccount(policy: .TwoOfThreeWith2FA, params: params) }
    }

    func didExistingRecoveryPhrase(_ mnemonic: String) {
        let cellModel = PolicyCellModel.from(policy: .TwoOfThreeWith2FA)
        let name = viewModel.uniqueName(cellModel.policy.accountType, liquid: viewModel.asset != "btc")
        let params = CreateSubaccountParams(name: name,
                                            type: .twoOfThree,
                                            recoveryMnemonic: mnemonic,
                                            recoveryXpub: nil)
        Task { await createSubaccount(policy: .TwoOfThreeWith2FA, params: params) }
    }
}
