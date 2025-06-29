import UIKit
import gdk
import core

enum HomeSection: Int, CaseIterable {
    case promo
    case remoteAlerts
    case swWallet
    case ephWallet
    case hwWallet
}

class HomeViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var newWalletView: UIView!
    @IBOutlet weak var lblNewWallet: UILabel!

    var headerH: CGFloat = 44.0
    var footerH: CGFloat = 54.0

    private var remoteAlert: RemoteAlert?
    var promoCardCellModel = [PromoCellModel]()
    var promoImpressionSent: Bool?

    private var ephAccounts: [Account] {
        AccountsRepository.shared.ephAccounts.filter { account in
            account.isEphemeral && !WalletsRepository.shared.wallets.filter {$0.key == account.id }.isEmpty
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()

        ["WalletListCell", "AlertCardCell", "PromoLayout0Cell", "PromoLayout1Cell", "PromoLayout2Cell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
        remoteAlert = RemoteAlertManager.shared.alerts(screen: .home, networks: []).first

        AnalyticsManager.shared.delegate = self
        AnalyticsManager.shared.recordView(.home)
        AnalyticsManager.shared.appLoadingFinished()
        PromoManager.shared.delegate = self
        loadNavigationBtns()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task {
            do {
                await self.reloadPromoCards()
                self.tableView.reloadData()
            }
        }
    }

    func setContent() {
        lblNewWallet.text = "id_setup_a_new_wallet".localized
    }

    func setStyle() {
        tableView.backgroundColor = UIColor.gBlackBg()
        newWalletView.setStyle(CardStyle.defaultStyle)
    }

    func loadNavigationBtns() {
        let settingsBtn = UIButton(type: .system)
        settingsBtn.contentEdgeInsets = UIEdgeInsets(top: 7.0, left: 7.0, bottom: 7.0, right: 7.0)
        settingsBtn.setImage(UIImage(named: "ic_nav_disclose"), for: .normal)
        settingsBtn.addTarget(self, action: #selector(settingsBtnTapped), for: .touchUpInside)
        let aboutBtn = UIButton(type: .system)
        aboutBtn.contentEdgeInsets = UIEdgeInsets(top: 7.0, left: 7.0, bottom: 7.0, right: 7.0)
        aboutBtn.setImage(UIImage(named: "ic_tab_security"), for: .normal)
        aboutBtn.addTarget(self, action: #selector(aboutBtnTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItems = [UIBarButtonItem(customView: settingsBtn), UIBarButtonItem(customView: aboutBtn)]
    }

    func remoteAlertDismiss() {
        remoteAlert = nil
        tableView.reloadData()
    }

    func remoteAlertLink() {
        SafeNavigationManager.shared.navigate(remoteAlert?.link)
    }

    func walletDelete(_ index: String) {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogDeleteViewController") as? DialogDeleteViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            vc.index = index
            present(vc, animated: false, completion: nil)
        }
    }

    func walletRename(_ index: String) {
        let account = AccountsRepository.shared.get(for: index)
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogRenameViewController") as? DialogRenameViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            vc.index = index
            vc.prefill = account?.name ?? ""
            present(vc, animated: false, completion: nil)
        }
    }

    func getAccountFromTableView(_ indexPath: IndexPath) -> Account? {
        switch HomeSection(rawValue: indexPath.section) {
        case .swWallet:
            return AccountsRepository.shared.swAccounts[indexPath.row]
        case .ephWallet:
            return ephAccounts[indexPath.row]
        case .hwWallet:
            return AccountsRepository.shared.hwVisibleAccounts[indexPath.row]
        default:
            return nil
        }
    }

    func goAccount(accountId: String) {
        if let wm = WalletsRepository.shared.get(for: accountId), wm.logged {
            AccountNavigator.navLogged(accountId: accountId)
        } else {
            if let vc = AccountNavigator.login(accountId: accountId, autologin: true) {
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    func onTapOverview(_ indexPath: IndexPath) {
        if let account = getAccountFromTableView(indexPath) {
            goAccount(accountId: account.id)
        }
    }

    func onTapLongPressOverview(_ indexPath: IndexPath, cell: UITableViewCell) {
        if let account = getAccountFromTableView(indexPath) {
            popover(for: cell, account: account)
        }
    }

    func isOverviewSelected(_ account: Account) -> Bool {
        WalletsRepository.shared.get(for: account.id)?.activeSessions.count ?? 0 > 0
    }

    func onPromo(_ promo: Promo) {
        if promo.is_small == true {
            PromoManager.shared.promoAction(promo: promo, source: .home)
            if let url = URL(string: promo.link ?? "") {
                SafeNavigationManager.shared.navigate(url, exitApp: true)
            }
        } else {
            PromoManager.shared.promoOpen(promo: promo, source: .home)
            let storyboard = UIStoryboard(name: "PromoFlow", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "PromoViewController") as? PromoViewController {
                vc.promo = promo
                vc.source = .home
                vc.modalPresentationStyle = .overFullScreen
                present(vc, animated: false, completion: nil)
            }
        }
    }

    // dismiss promo
    func promoDismiss() {
        Task {
            await reloadPromoCards()
            tableView.reloadData()
        }
    }

    func reloadPromoCards() async {
        promoCardCellModel = PromoManager.shared.promoCellModels(.home)
    }

    func promoImpression(_ promo: Promo) {
        if promoImpressionSent != true {
            promoImpressionSent = true
            PromoManager.shared.promoView(promo: promo, source: .home)
        }
    }

    @objc func settingsBtnTapped() {
        let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "WalletSettingsViewController") as? WalletSettingsViewController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    @objc func aboutBtnTapped() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogAboutViewController") as? DialogAboutViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            present(vc, animated: false, completion: nil)
        }
    }
    @IBAction func btnNewWallet(_ sender: Any) {
        newWalletView.pressAnimate {
            let hwFlow = UIStoryboard(name: "OnBoard", bundle: nil)
            if let vc = hwFlow.instantiateViewController(withIdentifier: "GetStartedOnBoardViewController") as? GetStartedOnBoardViewController {
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
}

extension HomeViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return HomeSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        switch HomeSection(rawValue: section) {
        case .promo:
            return promoCardCellModel.count
        case .remoteAlerts:
            return remoteAlert != nil ? 1 : 0
        case .swWallet:
            return AccountsRepository.shared.swAccounts.count
        case .ephWallet:
            return ephAccounts.count
        case .hwWallet:
            return AccountsRepository.shared.hwVisibleAccounts.count
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        switch HomeSection(rawValue: indexPath.section) {

        case .promo:
            let model = promoCardCellModel[indexPath.row]
            if model.promo.layout_small == 2 {
                if let cell = tableView.dequeueReusableCell(withIdentifier: "PromoLayout2Cell", for: indexPath) as? PromoLayout2Cell {
                    cell.configure(model, onAction: {[weak self] in
                        self?.onPromo(model.promo)
                    }, onDismiss: { [weak self] in
                        self?.promoDismiss()
                    })
                    cell.selectionStyle = .none
                    promoImpression(model.promo)
                    return cell
                }
            } else if model.promo.layout_small == 1 {
                if let cell = tableView.dequeueReusableCell(withIdentifier: "PromoLayout1Cell", for: indexPath) as? PromoLayout1Cell {
                    cell.configure(model, onAction: {[weak self] in
                        self?.onPromo(model.promo)
                    }, onDismiss: { [weak self] in
                        self?.promoDismiss()
                    })
                    cell.selectionStyle = .none
                    promoImpression(model.promo)
                    return cell
                }
            } else {
                if let cell = tableView.dequeueReusableCell(withIdentifier: "PromoLayout0Cell", for: indexPath) as? PromoLayout0Cell {
                    cell.configure(model, onAction: {[weak self] in
                        self?.onPromo(model.promo)
                    }, onDismiss: { [weak self] in
                        self?.promoDismiss()
                    })
                    cell.selectionStyle = .none
                    promoImpression(model.promo)
                    return cell
                }
            }
        case .remoteAlerts:
            if let cell = tableView.dequeueReusableCell(withIdentifier: "AlertCardCell", for: indexPath) as? AlertCardCell, let remoteAlert = self.remoteAlert {
                cell.configure(AlertCardCellModel(type: .remoteAlert(remoteAlert)),
                               onLeft: nil,
                               onRight: (remoteAlert.link ?? "" ).isEmpty ? nil : {[weak self] in
                    self?.remoteAlertLink() // to solve cylomatic complexity
                },
                               onDismiss: {[weak self] in
                    self?.remoteAlertDismiss()
                })
                cell.selectionStyle = .none
                return cell
            }
        case .swWallet:
            let account = AccountsRepository.shared.swAccounts[indexPath.row]
            if let cell = tableView.dequeueReusableCell(withIdentifier: "WalletListCell") as? WalletListCell {
                cell.configure(item: account,
                               indexPath: indexPath,
                               onLongpress: { [weak self] indexPath in self?.onTapLongPressOverview(indexPath, cell: cell) },
                               onTap: { [weak self] indexPath in self?.onTapOverview(indexPath) })
                cell.selectionStyle = .none
                return cell
            }
        case .ephWallet:
            let account = ephAccounts[indexPath.row]
            if let cell = tableView.dequeueReusableCell(withIdentifier: "WalletListCell") as? WalletListCell {
                cell.configure(item: account,
                               indexPath: indexPath,
                               onLongpress: nil,
                               onTap: { [weak self] indexPath in self?.onTapOverview(indexPath) })
                cell.selectionStyle = .none
                return cell
            }
        case .hwWallet:
            let account = AccountsRepository.shared.hwVisibleAccounts[indexPath.row]
            if let cell = tableView.dequeueReusableCell(withIdentifier: "WalletListCell") as? WalletListCell {
                cell.configure(
                    item: account,
                    indexPath: indexPath,
                    onLongpress: { [weak self] indexPath in self?.onTapLongPressOverview(indexPath, cell: cell) },
                    onTap: { [weak self] indexPath in self?.onTapOverview(indexPath) })
                cell.selectionStyle = .none
                return cell
            }
        default:
            break
        }

        return UITableViewCell()
    }

    func popover(for cell: UITableViewCell, account: Account) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let storyboard = UIStoryboard(name: "PopoverMenu", bundle: nil)
        if let popover  = storyboard.instantiateViewController(withIdentifier: "PopoverMenuHomeViewController") as? PopoverMenuHomeViewController {
            popover.delegate = self
            popover.index = account.id
            popover.menuOptions = [.edit, .delete]
            popover.modalPresentationStyle = .popover
            let popoverPresentationController = popover.popoverPresentationController
            popoverPresentationController?.backgroundColor = UIColor.customModalDark()
            popoverPresentationController?.delegate = self
            popoverPresentationController?.sourceView = cell
            popoverPresentationController?.sourceRect = cell.bounds
            present(popover, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch HomeSection(rawValue: section) {
        case .ephWallet:
            if ephAccounts.isEmpty {
                return 0.1
            }
        case .swWallet:
            if AccountsRepository.shared.swAccounts.isEmpty {
                return 0.1
            }
        case .hwWallet:
            if AccountsRepository.shared.hwVisibleAccounts.isEmpty {
                return 0.1
            }
        case .remoteAlerts, .promo:
            return 0.1
        default:
            break
        }
        return headerH
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch HomeSection(rawValue: section) {
        case .remoteAlerts, .promo:
            return nil
        case .swWallet:
            if AccountsRepository.shared.swAccounts.isEmpty {
                return nil
            }
            return headerView("id_digital_wallets".localized)
        case .ephWallet:
            if ephAccounts.isEmpty {
                return nil
            }
            return headerView("id_ephemeral_wallets".localized)
        case .hwWallet:
            if AccountsRepository.shared.hwVisibleAccounts.isEmpty {
                return nil
            }
            return headerView("id_hardware_wallets".localized)
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    }
}

extension HomeViewController {
    func headerView(_ txt: String) -> UIView {
        let section = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: headerH))
        section.backgroundColor = .clear
        let title = UILabel(frame: .zero)
        title.text = txt
        title.numberOfLines = 0
        title.setStyle(.txtBigger)
        title.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(title)
        NSLayoutConstraint.activate([
            title.centerYAnchor.constraint(equalTo: section.centerYAnchor),
            title.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 25),
            title.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -25)
        ])
        return section
    }
}

extension HomeViewController: AnalyticsManagerDelegate {
    func remoteConfigIsReady() {
        DispatchQueue.main.async {
            self.remoteAlert = RemoteAlertManager.shared.alerts(screen: .home, networks: []).first
            self.tableView.reloadData()
        }
    }
}

extension HomeViewController: UIPopoverPresentationControllerDelegate {

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }

    func presentationController(_ controller: UIPresentationController, viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle) -> UIViewController? {
        return UINavigationController(rootViewController: controller.presentedViewController)
    }
}

extension HomeViewController: PopoverMenuHomeDelegate {
    func didSelectionMenuOption(menuOption: MenuWalletOption, index: String?) {
        guard let index = index else { return }
        switch menuOption {
        case .edit:
            walletRename(index)
        case .delete:
            walletDelete(index)
        default:
            break
        }
    }
}

extension HomeViewController: DialogRenameViewControllerDelegate, DialogDeleteViewControllerDelegate {
    func didRename(name: String, index: String?) {
        if let index = index, var account = AccountsRepository.shared.get(for: index) {
            account.name = name
            AccountsRepository.shared.upsert(account)
            AnalyticsManager.shared.renameWallet()
            tableView.reloadData()
        }
    }
    func didDelete(_ index: String?) {
        if let index = index, let account = AccountsRepository.shared.get(for: index) {
            Task {
                self.startLoader(message: "Removing wallet…".localized)
                await AccountsRepository.shared.remove(account)
                await MainActor.run {
                    self.stopLoader()
                    AnalyticsManager.shared.deleteWallet()
                    tableView.reloadData()
                }
            }
        }
    }
    func didCancel() {
    }
}

extension HomeViewController: PromoManagerDelegate {
    func preloadDidEnd() {
        Task {
            do {
                await self.reloadPromoCards()
                self.tableView.reloadData()
            }
        }
    }
}

extension HomeViewController: DialogAboutViewControllerDelegate {
    func openContactUs() {
        presentContactUsViewController(request: ZendeskErrorRequest(shareLogs: true))
    }
}
