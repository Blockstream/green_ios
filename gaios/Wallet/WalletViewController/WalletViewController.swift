import UIKit
import PromiseKit

enum WalletSection: Int, CaseIterable {
    case card
    case balance
    case account
    case transaction
    case footer
}

class WalletViewController: UIViewController {

    enum FooterType {
        case noTransactions
        case none
    }

    enum WalletPreferences: String, CaseIterable {
        case WalletSettings = "Wallet Settings"
        case ArchivedAccounts = "Archived Accounts"
        case CreateNewAccount = "Create a New Account"
    }

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var actionsBg: UIView!
    @IBOutlet weak var btnSend: UIButton!
    @IBOutlet weak var btnReceive: UIButton!
    @IBOutlet weak var welcomeLayer: UIView!
    @IBOutlet weak var lblWelcomeTitle: UILabel!
    @IBOutlet weak var lblWelcomeHint: UILabel!
    @IBOutlet weak var btnWelcomeCreate: UIButton!

    //    var assetId: String?

    private var headerH: CGFloat = 54.0
    private var footerH: CGFloat = 54.0
    private var cardH: CGFloat = 64.0
    private var cardHc: CGFloat = 184.0
    private var hideBalance: Bool {
        get {
            return UserDefaults.standard.bool(forKey: AppStorage.hideBalance)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: AppStorage.hideBalance)
        }
    }
    private var sIdx: Int = 0
    private var userWillLogout = false

    var viewModel: WalletViewModel = WalletViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        ["AccountCell", "BalanceCell", "TransactionCell", "AlertCardCell" ].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
        let reloadSections: (([WalletSection], Bool) -> Void)? = { [weak self] (sections, animated) in
            self?.reloadSections(sections, animated: true)
        }
        viewModel.reloadSections = reloadSections
        setContent()
        setStyle()
        welcomeLayer.isHidden = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if userWillLogout == true { return }
        viewModel.loadSubaccounts()
        viewModel.reloadAlertCards()
    }

    func reloadSections(_ sections: [WalletSection], animated: Bool) {
        if animated {
            tableView.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
        } else {
            UIView.performWithoutAnimation {
                tableView.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
            }
        }
        if sections.contains(WalletSection.account) {
            tableView.selectRow(at: IndexPath(row: sIdx, section: WalletSection.account.rawValue), animated: false, scrollPosition: .none)
        }
        welcomeLayer.isHidden = viewModel.accountCellModels.count > 0
    }

    func setContent() {
        lblWelcomeTitle.text = "Welcome to your Wallet!"
        lblWelcomeHint.text = "Create your first account to receive funds."
        btnWelcomeCreate.setTitle("Create Account", for: .normal)
        let drawerItem = ((Bundle.main.loadNibNamed("DrawerBarItem", owner: self, options: nil)![0] as? DrawerBarItem)!)
        drawerItem.configure {
            [weak self] () in
                self?.switchNetwork()
        }
        let leftItem: UIBarButtonItem = UIBarButtonItem(customView: drawerItem)
        navigationItem.leftBarButtonItem = leftItem

        // setup right menu bar: settings
        let settingsBtn = UIButton(type: .system)
        settingsBtn.setImage(UIImage(named: "ic_gear"), for: .normal)
        settingsBtn.addTarget(self, action: #selector(settingsBtnTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: settingsBtn)

        btnSend.setTitle( "id_send".localized, for: .normal )
        btnReceive.setTitle( "id_receive".localized, for: .normal )

        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl!.tintColor = UIColor.white
        tableView.refreshControl!.addTarget(self, action: #selector(handleRefresh(_:)), for: .valueChanged)
    }

    func setStyle() {
        actionsBg.layer.cornerRadius = 5.0
        btnWelcomeCreate.setStyle(.primary)
    }

    // tableview refresh gesture
    @objc func handleRefresh(_ sender: UIRefreshControl? = nil) {
    }

    // open wallet selector drawer
    @objc func switchNetwork() {
        let storyboard = UIStoryboard(name: "DrawerNetworkSelection", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DrawerNetworkSelection") as? DrawerNetworkSelectionViewController {
            vc.transitioningDelegate = self
            vc.modalPresentationStyle = .custom
            vc.delegate = self
            present(vc, animated: true, completion: nil)
        }
    }

    // open settings
    @objc func settingsBtnTapped(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {
            vc.delegate = self
            vc.viewModel = DialogListViewModel(title: "Wallet Preferences", type: .walletPrefs, items: WalletPrefs.getItems())
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    // open send flow
    func sendfromWallet() {
        let storyboard = UIStoryboard(name: "Send", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendViewController") as? SendViewController {
            let model = viewModel.accountCellModels[sIdx]
            vc.wallet = model.account
            vc.fixedWallet = false
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    // open receive screen
    func receiveScreen() {
        let storyboard = UIStoryboard(name: "Wallet", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ReceiveViewController") as? ReceiveViewController {
            let model = viewModel.accountCellModels[sIdx]
            vc.viewModel = ReceiveViewModel(account: model.account,
                                            accounts: viewModel.subaccounts)
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func assetsScreen() {
        let storyboard = UIStoryboard(name: "Wallet", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AssetsViewController") as? AssetsViewController {
            vc.viewModel = AssetsViewModel(assetCellModels: viewModel.walletAssetCellModels)
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func accountDetail(model: AccountCellModel?) {
        guard let model = model else { return }
        let storyboard = UIStoryboard(name: "Wallet", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AccountViewController") as? AccountViewController {
            vc.viewModel = AccountViewModel(model: model, account: model.account, cachedBalance: viewModel.cachedBalance)
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func createAccount() {
        let storyboard = UIStoryboard(name: "Utility", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SecuritySelectViewController") as? SecuritySelectViewController {
            vc.viewModel = SecuritySelectViewModel(asset: "btc")
            vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    // dismiss remote alert
    func remoteAlertDismiss() {
        viewModel.remoteAlert = nil
        viewModel.reloadAlertCards()
    }

    // open system message view
    func systemMessageScreen(msg: SystemMessage) {
        let storyboard = UIStoryboard(name: "Wallet", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SystemMessageViewController") as? SystemMessageViewController {
            vc.msg = msg
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    // open Learn 2fa controller for reset/dispute wallet
    func twoFactorResetMessageScreen(msg: TwoFactorResetMessage) {
        let storyboard = UIStoryboard(name: "Wallet", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "Learn2faViewController") as? Learn2faViewController {
            vc.message = msg
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    @IBAction func btnSend(_ sender: Any) {
        sendfromWallet()
    }

    @IBAction func btnReceive(_ sender: Any) {
        receiveScreen()
    }

    @IBAction func btnWelcomeCreate(_ sender: Any) {
        createAccount()
    }
}

extension WalletViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return WalletSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        switch WalletSection(rawValue: section) {
        case .balance:
            return viewModel.balanceCellModel == nil ? 0 : 1
        case .account:
            return viewModel.accountCellModels.count
        case .card:
            return viewModel.alertCardCellModel.count
        case .transaction:
            return viewModel.txCellModels.count
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        switch WalletSection(rawValue: indexPath.section) {
        case .balance:
            if let cell = tableView.dequeueReusableCell(withIdentifier: BalanceCell.identifier, for: indexPath) as? BalanceCell, let model = viewModel.balanceCellModel {
                cell.configure(model: model,
                               hideBalance: hideBalance,
                               onHide: {[weak self] value in
                    self?.hideBalance = value
                },
                               onAssets: {[weak self] in
                    self?.assetsScreen()
                })
                cell.selectionStyle = .none
                return cell
            }
        case .account:
            if let cell = tableView.dequeueReusableCell(withIdentifier: AccountCell.identifier, for: indexPath) as? AccountCell {

                cell.configure(model: viewModel.accountCellModels[indexPath.row],
                               cIdx: indexPath.row,
                               sIdx: sIdx,
                               isLast: indexPath.row == viewModel.accountCellModels.count - 1,
                               onSelect: {[weak self] in
                    self?.accountDetail(model: self?.viewModel.accountCellModels[indexPath.row])
                }, onCopy: nil
                )
                cell.selectionStyle = .none
                return cell
            }
        case .card:
            if let cell = tableView.dequeueReusableCell(withIdentifier: "AlertCardCell", for: indexPath) as? AlertCardCell {
                let alertCard = viewModel.alertCardCellModel[indexPath.row]
                switch alertCard.type {
                case .reset(let msg), .dispute(let msg):
                    cell.configure(viewModel.alertCardCellModel[indexPath.row],
                                   onLeft: nil,
                                   onRight: {[weak self] in
                                        self?.twoFactorResetMessageScreen(msg: msg)
                                    }, onDismiss: nil)
                case .reactivate:
                    cell.configure(viewModel.alertCardCellModel[indexPath.row],
                                   onLeft: nil,
                                   onRight: nil,
                                   onDismiss: nil)
                case .systemMessage(let msg):
                    cell.configure(viewModel.alertCardCellModel[indexPath.row],
                                   onLeft: nil,
                                   onRight: {[weak self] in
                                        self?.systemMessageScreen(msg: msg)
                                    },
                                   onDismiss: nil)
                case .fiatMissing:
                    cell.configure(viewModel.alertCardCellModel[indexPath.row],
                                   onLeft: nil,
                                   onRight: nil,
                                   onDismiss: nil)
                case .testnetNoValue:
                    cell.configure(viewModel.alertCardCellModel[indexPath.row],
                                   onLeft: nil,
                                   onRight: nil,
                                   onDismiss: nil)
                case .ephemeralWallet:
                    cell.configure(viewModel.alertCardCellModel[indexPath.row],
                                   onLeft: nil,
                                   onRight: nil,
                                   onDismiss: nil)
                case .remoteAlert:
                    cell.configure(viewModel.alertCardCellModel[indexPath.row],
                                   onLeft: nil,
                                   onRight: (viewModel.remoteAlert?.link ?? "" ).isEmpty ? nil : {[weak self] in
                        if let url = URL(string: self?.viewModel.remoteAlert?.link ?? "") {
                            UIApplication.shared.open(url)
                        }
                    },
                                   onDismiss: {[weak self] in
                        self?.remoteAlertDismiss()
                    })
                }
                cell.selectionStyle = .none
                return cell
            }
        case .transaction:
            if let cell = tableView.dequeueReusableCell(withIdentifier: TransactionCell.identifier, for: indexPath) as? TransactionCell {
                cell.configure(model: viewModel.txCellModels[indexPath.row])
                cell.selectionStyle = .none
                return cell
            }
        default:
            break
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch WalletSection(rawValue: section) {
        case .transaction:
            return headerH
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch WalletSection(rawValue: section) {
        case .transaction:
            return viewModel.cachedTransactions.count == 0 ? footerH : 1.0
        case .footer:
            return 100.0
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {

        switch WalletSection(rawValue: indexPath.section) {
        case .account:
            return indexPath.row == sIdx ? cardHc : cardH
        default:
            return UITableView.automaticDimension
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {

        switch WalletSection(rawValue: section) {
        case .transaction:
            return headerView( "Latest transactions" )
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        switch WalletSection(rawValue: section) {
        case .account:
            return footerView(.none)
        case .transaction:
            return viewModel.cachedTransactions.count == 0 ? footerView(.noTransactions) : footerView(.none)
        default:
            return footerView(.none)
        }
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch WalletSection(rawValue: indexPath.section) {
        case .balance:
            return nil
        default:
            return indexPath
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        switch WalletSection(rawValue: indexPath.section) {
        case .account:
            sIdx = indexPath.row
            tableView.beginUpdates()
            tableView.endUpdates()
        case .transaction:
            let transaction = viewModel.cachedTransactions[indexPath.row]
            let storyboard = UIStoryboard(name: "Transaction", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "TransactionViewController") as? TransactionViewController {
                vc.transaction = transaction
                navigationController?.pushViewController(vc, animated: true)
            }
            tableView.deselectRow(at: indexPath, animated: false)
            tableView.selectRow(at: IndexPath(row: sIdx, section: WalletSection.account.rawValue), animated: false, scrollPosition: .none)
        default:
            break
        }
    }
}

extension WalletViewController: DialogWalletNameViewControllerDelegate {

    func didRename(name: String, index: Int?) {
        //...
    }
    func didCancel() {
    }
}

extension WalletViewController: UserSettingsViewControllerDelegate, Learn2faViewControllerDelegate {
    func userLogout() {
        userWillLogout = true
        self.presentedViewController?.dismiss(animated: true, completion: {
            DispatchQueue.main.async {
                if let account = AccountsManager.shared.current {
                    WalletManager.delete(for: account.id)
                }
                let storyboard = UIStoryboard(name: "Home", bundle: nil)
                let nav = storyboard.instantiateViewController(withIdentifier: "HomeViewController") as? UINavigationController
                UIApplication.shared.keyWindow?.rootViewController = nav
            }
        })
    }

    func refresh() {
        viewModel.loadSubaccounts()
    }
}

extension WalletViewController: UIPopoverPresentationControllerDelegate {

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }

    func presentationController(_ controller: UIPresentationController, viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle) -> UIViewController? {
        return UINavigationController(rootViewController: controller.presentedViewController)
    }
}

extension WalletViewController {

    func headerView(_ txt: String) -> UIView {

        let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: headerH))
        section.backgroundColor = UIColor.clear
        let title = UILabel(frame: .zero)
        title.font = .systemFont(ofSize: 18.0, weight: .heavy)
        title.text = txt
        title.textColor = .white
        title.numberOfLines = 0

        title.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(title)

        NSLayoutConstraint.activate([
            title.centerYAnchor.constraint(equalTo: section.centerYAnchor, constant: 10.0),
            title.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 20),
            title.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: 20)
        ])

        return section
    }

    func footerView(_ type: FooterType) -> UIView {

        switch type {
        case .none:
            let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 1.0))
            section.backgroundColor = .clear
            return section
        case .noTransactions:
            let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: footerH))
            section.backgroundColor = .clear

            let lblNoTransactions = UILabel(frame: .zero)
            lblNoTransactions.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            lblNoTransactions.textColor = UIColor.gGrayTxt()
            lblNoTransactions.numberOfLines = 0
            lblNoTransactions.textAlignment = .center
            lblNoTransactions.text = NSLocalizedString("id_your_transactions_will_be_shown", comment: "")
            lblNoTransactions.translatesAutoresizingMaskIntoConstraints = false
            section.addSubview(lblNoTransactions)

            NSLayoutConstraint.activate([
                lblNoTransactions.topAnchor.constraint(equalTo: section.topAnchor, constant: 0.0),
                lblNoTransactions.bottomAnchor.constraint(equalTo: section.bottomAnchor, constant: 0.0),
                lblNoTransactions.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 40.0),
                lblNoTransactions.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -40.0)
            ])

            if viewModel.isTxLoading {
                let loader = UIActivityIndicatorView(style: .white)
                section.addSubview(loader)
                loader.startAnimating()
                loader.translatesAutoresizingMaskIntoConstraints = false
                let horizontalConstraint = NSLayoutConstraint(item: loader,
                                                              attribute: .left,
                                                              relatedBy: .equal,
                                                              toItem: section,
                                                              attribute: .left,
                                                              multiplier: 1,
                                                              constant: 20.0)
                let verticalConstraint = NSLayoutConstraint(item: loader,
                                                            attribute: .centerY,
                                                            relatedBy: .equal,
                                                            toItem: lblNoTransactions,
                                                            attribute: .centerY,
                                                            multiplier: 1,
                                                            constant: 0)
                NSLayoutConstraint.activate([horizontalConstraint, verticalConstraint])
            }
            return section
        }

    }
}

extension WalletViewController: UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        if let presented = presented as? DrawerNetworkSelectionViewController {
            return DrawerPresentationController(presentedViewController: presented, presenting: presenting)
        }
        return ModalPresentationController(presentedViewController: presented, presenting: presenting)
    }

    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if presented as? DrawerNetworkSelectionViewController != nil {
            return DrawerAnimator(isPresenting: true)
        } else {
            return ModalAnimator(isPresenting: true)
        }
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if dismissed as? DrawerNetworkSelectionViewController != nil {
            return DrawerAnimator(isPresenting: false)
        } else {
            return ModalAnimator(isPresenting: false)
        }
    }
}

extension WalletViewController: DrawerNetworkSelectionDelegate {

    // accounts drawer: add new waller
    func didSelectAddWallet() {
        AccountNavigator.goCreateRestore()
    }

    // accounts drawer: select another account
    func didSelectAccount(account: Account) {
        // don't switch if same account selected
        if account.id == AccountsManager.shared.current?.id ?? "" {
            return
        }
        AccountNavigator.goLogin(account: account)
    }

    // accounts drawer: select hw account
    func didSelectHW(account: Account) {
        AccountNavigator.goHWLogin(isJade: account.isJade)
    }

    // accounts drawer: select app settings
    func didSelectSettings() {
        self.presentedViewController?.dismiss(animated: true, completion: {
            let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "WalletSettingsViewController") as? WalletSettingsViewController {
                self.present(vc, animated: true) {}
            }
        })
    }

    func didSelectAbout() {
        self.presentedViewController?.dismiss(animated: true, completion: {
            let storyboard = UIStoryboard(name: "About", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "AboutViewController") as? AboutViewController {
                self.navigationController?.pushViewController(vc, animated: true)
            }
        })
    }
}

extension WalletViewController: DialogListViewControllerDelegate {
    func didSelectIndex(_ index: Int, with type: DialogType) {
        switch type {
        case .walletPrefs:
            switch WalletPrefs(rawValue: index) {
            case .settings:
                let storyboard = UIStoryboard(name: "UserSettings", bundle: nil)
                let nvc = storyboard.instantiateViewController(withIdentifier: "UserSettingsNavigationController")
                if let nvc = nvc as? UINavigationController {
                    if let vc = nvc.viewControllers.first as? UserSettingsViewController {
                        vc.delegate = self
                        nvc.modalPresentationStyle = .fullScreen
                        present(nvc, animated: true, completion: nil)
                    }
                }
            case .createAccount:
                createAccount()
    //        case .ArchivedAccounts:
    //            let storyboard = UIStoryboard(name: "Accounts", bundle: nil)
    //            if let vc = storyboard.instantiateViewController(withIdentifier: "AccountArchiveViewController") as? AccountArchiveViewController {
    //                navigationController?.pushViewController(vc, animated: true)
    //            }
            case .none:
                break
            }
        case .enable2faPrefs:
            switch Enable2faPrefs(rawValue: index) {
            case .add:
                print("handle action here")
            default:
                break
            }
        default:
            break
        }
    }
}
extension WalletViewController: SecuritySelectViewControllerDelegate {
    func didCreatedWallet(_ wallet: WalletItem) {
        let accountCellModel = AccountCellModel(subaccount: wallet)
        accountDetail(model: accountCellModel)
    }
}
