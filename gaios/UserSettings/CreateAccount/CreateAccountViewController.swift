import UIKit
import core
import hw

enum CreateAccountListSection: Int, CaseIterable {
    case asset
    case policy
}

protocol CreateAccountDelegate: AnyObject {
    func didCreateAccount()
    func didUnarchiveAccount()
}

class CreateAccountViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var btnAdvanced: UIButton!
    @IBOutlet var tableViewToAdvancedButtonConstraint: NSLayoutConstraint!
    @IBOutlet var tableViewToSafeAreaConstraint: NSLayoutConstraint!

    private let headerH: CGFloat = 54.0
    weak var delegate: CreateAccountDelegate?
    private var viewModel: CreateAccountViewModel
    var dialogJadeCheckViewController: DialogJadeCheckViewController?
    private var isCreating = false
    private var pendingPolicy: AccountTypeOption?
    private var pendingParams: CreateSubaccountParams?

    init?(coder: NSCoder, viewModel: CreateAccountViewModel) {
        self.viewModel = viewModel
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    deinit {
        viewModel.unarchiveCreateDialog = nil
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            viewModel.unarchiveCreateDialog = nil
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel.unarchiveCreateDialog = { [weak self] completion in
            self?.unarchiveCreateDialog(completion: completion)
        }

        [AccountTypeCell.identifier, AssetSelectCell.identifier].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
        tableView.sectionHeaderTopPadding = 0

        setContent()
        setStyle()
        updateAdvancedOptionsLayout()

        let wallet = WalletsStorage.shared.current
        AnalyticsManager.shared.recordView(.addAccountChooseType, sgmt: AnalyticsManager.shared.sessSgmt(wallet))
    }

    func setContent() {
        title = "id_create_new_account".localized
        btnAdvanced.setTitle(viewModel.isAllPoliciesShown ? "id_hide_advanced_options".localized : "id_show_advanced_options".localized, for: .normal)
    }

    func setStyle() {
        btnAdvanced.setStyle(.inline)
    }

    func updateAdvancedOptionsLayout() {
        let isAdvancedHidden = !viewModel.isAdvancedEnable()
        btnAdvanced.isHidden = isAdvancedHidden

        if isAdvancedHidden {
            tableViewToAdvancedButtonConstraint.isActive = false
            tableViewToSafeAreaConstraint.isActive = true
        } else {
            tableViewToSafeAreaConstraint.isActive = false
            tableViewToAdvancedButtonConstraint.isActive = true
        }
    }

    func unarchiveCreateDialog(completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: "id_archived_account".localized, message: "id_there_is_already_an_archived".localized, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "id_unarchive_account".localized, style: .cancel) { (_: UIAlertAction) in
            completion(false)
        })
        alert.addAction(UIAlertAction(title: "id_create".localized, style: .default) { (_: UIAlertAction) in
            completion(true)
        })
        DispatchQueue.main.async { [weak self] in
            self?.presentOnTop(alert)
        }
    }

    func presentOnTop(_ viewController: UIViewController, animated: Bool = true) {
        var presenter: UIViewController = navigationController ?? self
        while let presented = presenter.presentedViewController, !presented.isBeingDismissed {
            presenter = presented
        }
        presenter.present(viewController, animated: animated)
    }

    @MainActor
    func reloadSections(_ sections: [CreateAccountListSection], animated: Bool) {
        updateAdvancedOptionsLayout()

        if animated {
            tableView.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
        } else {
            UIView.performWithoutAnimation {
                tableView.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
            }
        }
    }

    @IBAction func btnAdvanced(_ sender: Any) {
        let oldCount = viewModel.getAccountCellModels().count
        viewModel.isAllPoliciesShown.toggle()
        let newCount = viewModel.getAccountCellModels().count

        setContent()

        if newCount > oldCount {
            let indexPaths = (oldCount..<newCount).map { IndexPath(row: $0, section: CreateAccountListSection.policy.rawValue) }
            tableView.insertRows(at: indexPaths, with: .automatic)
        } else if newCount < oldCount {
            let indexPaths = (newCount..<oldCount).map { IndexPath(row: $0, section: CreateAccountListSection.policy.rawValue) }
            tableView.deleteRows(at: indexPaths, with: .automatic)
        }
    }
}

extension CreateAccountViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return CreateAccountListSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        switch CreateAccountListSection(rawValue: section) {
        case .asset:
            return 1
        case .policy:
            return viewModel.getAccountCellModels().count ?? 0
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        btnAdvanced.isHidden = !viewModel.isAdvancedEnable()

        switch CreateAccountListSection(rawValue: indexPath.section) {
        case .asset:
            if let cell = tableView.dequeueReusableCell(withIdentifier: AssetSelectCell.identifier, for: indexPath) as? AssetSelectCell,
               let model = viewModel.assetCellModel {
                cell.configure(model: model, showEditIcon: true)
                cell.selectionStyle = .none
                return cell
            }
        case .policy:
            if let cell = tableView.dequeueReusableCell(withIdentifier: AccountTypeCell.identifier, for: indexPath) as? AccountTypeCell {
                cell
                    .configure(
                        model: viewModel.getAccountCellModels()[indexPath.row],
                        hasLightning: viewModel.hasLightning()
                    )
                cell.selectionStyle = .none
                return cell
            }
        default:
            break
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch CreateAccountListSection(rawValue: section) {
        default:
            return headerH
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch CreateAccountListSection(rawValue: indexPath.section) {
        default:
            return UITableView.automaticDimension
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch CreateAccountListSection(rawValue: section) {
        case .asset:
            return headerView("id_asset".localized)
        case .policy:
            return headerView("id_security_policy".localized)
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch CreateAccountListSection(rawValue: indexPath.section) {
        default:
            return indexPath
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch CreateAccountListSection(rawValue: indexPath.section) {
        case .asset:
            let storyboard = UIStoryboard(name: "Utility", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "AssetSelectViewController") as? AssetSelectViewController {
                let allAssets = WalletManager.current?.registry.all.filter({$0.assetId != "lightning"})
                let assetInfos = viewModel.onlyBtc ? [AssetInfo.btc] : allAssets
                let assetIds = assetInfos?.map { ($0.assetId, Int64(0)) }
                let dict = Dictionary(uniqueKeysWithValues: assetIds ?? [])
                let list = AssetAmountList(dict)
                vc.viewModel = AssetSelectViewModel(assets: list,
                                                    enableAnyLiquidAsset: viewModel.onlyBtc ? false : true,
                                                    enableAnyAmpAsset: false,
                                                    enableAnyAmpLegacyAsset: false)
                vc.delegate = self
                navigationController?.pushViewController(vc, animated: true)
            }
        case .policy:
            let policy = viewModel.getAccountCellModels()[indexPath.row].policy
            if policy == .TwoOfThreeWith2FA {
                let storyboard = UIStoryboard(name: "Accounts", bundle: nil)
                if let vc = storyboard.instantiateViewController(withIdentifier: "AccountCreateRecoveryKeyViewController") as? AccountCreateRecoveryKeyViewController {
                    if let network = policy.getNetwork(testnet: WalletManager.current?.testnet ?? false,
                                                       liquid: viewModel.asset != "btc") {
                        let session = viewModel.wm.gdkNetworkBackendOrNil(
                            network
                        )?.session
                        vc.session = session
                        vc.delegate = self
                        navigationController?.pushViewController(vc, animated: true)
                    }
                }
            } else {
                let isLiquid = viewModel.isLiquidSelection
                let params = CreateSubaccountParams(
                    name: viewModel.uniqueName(policy.accountType, liquid: isLiquid),
                    type: policy.accountType,
                    recoveryMnemonic: nil,
                    recoveryXpub: nil)
                requestCreateSubaccount(policy: policy, params: params)
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
    func hideHWCheckDialog(completion: (() -> Void)? = nil) {
        guard let dialog = dialogJadeCheckViewController, dialog.presentingViewController != nil else {
            dialogJadeCheckViewController = nil
            completion?()
            return
        }
        dialog.dismiss(animated: false) { [weak self] in
            self?.dialogJadeCheckViewController = nil
            completion?()
        }
    }

    @MainActor
    func presentConnectViewController() {
        let storyboard = UIStoryboard(name: "HWDialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "HWDialogConnectViewController") as? HWDialogConnectViewController {
            vc.delegate = self
            vc.authentication = true
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @MainActor
    func requestCreateSubaccount(policy: AccountTypeOption, params: CreateSubaccountParams) {
        if viewModel.needsBluetoothAccess(policy: policy) {
            showJadeBluetoothDiscoveryAlert() {
                self.pendingPolicy = policy
                self.pendingParams = params
                self.connectOrCreatePendingSubaccount()
            } cancel: {
                self.pendingPolicy = nil
                self.pendingParams = nil
            }
            return
        }
        createSubaccount(policy: policy, params: params)
    }

    func connectOrCreatePendingSubaccount() {
        if !BleHwManager.shared.isConnected() || !BleHwManager.shared.isLogged() {
            presentConnectViewController()
            return
        }
        guard let policy = pendingPolicy, let params = pendingParams else { return }
        pendingPolicy = nil
        pendingParams = nil
        createSubaccount(policy: policy, params: params)
    }

    @MainActor
    func createSubaccount(policy: AccountTypeOption, params: CreateSubaccountParams) {
        guard !isCreating else { return }
        isCreating = true
        tableView.isUserInteractionEnabled = false
        let isHW = WalletsStorage.shared.current?.isHW ?? false
        if isHW {
            showHWCheckDialog()
        } else {
            startLoader(message: String(format: "id_creating_your_s_account".localized, policy.accountType.description))
        }
        Task { [weak self] in
            let task = Task { [weak self] in
                try await self?.viewModel.create(policy: policy, params: params)
            }
            switch await task.result {
            case .success(let action):
                self?.stopLoader()
                if isHW {
                    self?.hideHWCheckDialog()
                    if self?.viewModel.needsBluetoothAccess(policy: policy) == true {
                        self?.viewModel.disableBiometric()
                    }
                }
                switch action {
                case .created:
                    self?.didCreateWallet()
                case .unarchived:
                    self?.didUnarchiveWallet()
                case .none:
                    break
                }
                self?.navigationController?.popToRootViewController(animated: true)
            case .failure(let error):
                self?.isCreating = false
                self?.tableView.isUserInteractionEnabled = true
                self?.stopLoader()
                if isHW {
                    self?.hideHWCheckDialog {
                        self?.showError(error)
                    }
                } else {
                    self?.showError(error)
                }
            }
        }
    }

    func showJadeBluetoothDiscoveryAlert(next: @escaping () -> Void, cancel: @escaping () -> Void) {
        let alert = UIAlertController(
            title: "id_connect_with_bluetooth".localized,
            message: "Connect your Jade via Bluetooth to show all subaccounts. Watch-only biometric access will be disabled.",
            preferredStyle: .alert
        )
        alert
            .addAction(
                UIAlertAction(
                    title: "id_cancel".localized,
                    style: .cancel
                ) {_ in 
            cancel()
        })
        alert
            .addAction(
                UIAlertAction(
                    title: "id_continue".localized,
                    style: .default
                ) {_ in
            DispatchQueue.main.async {
                next()
            }
        })
        presentOnTop(alert)
    }
}

extension CreateAccountViewController {
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
            title.topAnchor.constraint(equalTo: section.topAnchor, constant: 20),
            title.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 25),
            title.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: 25)
        ])

        return section
    }
}

extension CreateAccountViewController: AssetSelectViewControllerDelegate {
    func didSelectAnyOrAsset(_ ref: AnyOrAsset) {
        viewModel.resetSelection()
        switch ref {
        case .anyLiquid:
            viewModel.anyLiquidAsset = true
            reloadSections([.asset, .policy], animated: true)
        case .anyAmp:
            viewModel.anyLiquidAmpAsset = true
            reloadSections([.asset, .policy], animated: true)
        case .anyAmpLegacy:
            viewModel.anyLiquidAmpLegacyAsset = true
            reloadSections([.asset, .policy], animated: true)
        case .asset(let assetId):
            viewModel.asset = assetId
            reloadSections([.asset, .policy], animated: true)
        }
    }

    @MainActor
    func didCreateWallet() {
        DropAlert().success(message: "id_new_account_created".localized)
        delegate?.didCreateAccount()
    }
    @MainActor
    func didUnarchiveWallet() {
        DropAlert().success(message: "id_unarchive_account".localized)
        delegate?.didUnarchiveAccount()
    }
}

extension CreateAccountViewController: AccountCreateRecoveryKeyDelegate {
    func didPublicKey(_ key: String) {
        let cellModel = AccountTypeCellModel.from(policy: .TwoOfThreeWith2FA)
        let name = viewModel.uniqueName(cellModel.policy.accountType, liquid: viewModel.asset != "btc")
        let params = CreateSubaccountParams(name: name,
                                            type: .twoOfThree,
                                            recoveryMnemonic: nil,
                                            recoveryXpub: key)
        requestCreateSubaccount(policy: .TwoOfThreeWith2FA, params: params)
    }

    func didNewRecoveryPhrase(_ mnemonic: String) {
        let cellModel = AccountTypeCellModel.from(policy: .TwoOfThreeWith2FA)
        let name = viewModel.uniqueName(cellModel.policy.accountType, liquid: viewModel.asset != "btc")
        let params = CreateSubaccountParams(name: name,
                                            type: .twoOfThree,
                                            recoveryMnemonic: mnemonic,
                                            recoveryXpub: nil)
        requestCreateSubaccount(policy: .TwoOfThreeWith2FA, params: params)
    }

    func didExistingRecoveryPhrase(_ mnemonic: String) {
        let cellModel = AccountTypeCellModel.from(policy: .TwoOfThreeWith2FA)
        let name = viewModel.uniqueName(cellModel.policy.accountType, liquid: viewModel.asset != "btc")
        let params = CreateSubaccountParams(name: name,
                                            type: .twoOfThree,
                                            recoveryMnemonic: mnemonic,
                                            recoveryXpub: nil)
        requestCreateSubaccount(policy: .TwoOfThreeWith2FA, params: params)
    }
}

extension CreateAccountViewController: HWDialogConnectViewControllerDelegate {
    func connected() {}

    func logged() {
        guard let policy = pendingPolicy, let params = pendingParams else { return }
        pendingPolicy = nil
        pendingParams = nil
        createSubaccount(policy: policy, params: params)
    }

    func cancel() {
        pendingPolicy = nil
        pendingParams = nil
    }

    func failure(err: Error) {
        pendingPolicy = nil
        pendingParams = nil
        showError(err)
    }
}
