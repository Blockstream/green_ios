import UIKit
import gdk
import core
import ObjectiveC

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
    @IBOutlet weak var lblWallets: UILabel!
    @IBOutlet weak var btnNewWallet: UIButton!

    var headerH: CGFloat = 44.0
    var footerH: CGFloat = 54.0

    private var remoteAlert: RemoteAlert?
    var promoCardCellModel = [PromoCellModel]()
    var promoImpressionSent: Bool?

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
        view.accessibilityIdentifier = AccessibilityIds.HomeScreen.view
        btnNewWallet.accessibilityIdentifier = AccessibilityIds.HomeScreen.btnSetUpNewWallet
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
        lblNewWallet.text = "id_set_up_a_new_wallet".localized
        lblWallets.text = "id_my_wallets".localized
    }

    func setStyle() {
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.backgroundColor = UIColor.gBlackBg()
        newWalletView.setStyle(CardStyle.defaultStyle)
        lblWallets.setStyle(.txtBigger)
        lblWallets.textColor = UIColor.gGrayTxt()
    }

    func loadNavigationBtns() {
        let settingsBtn = UIButton(type: .system)
        settingsBtn.contentEdgeInsets = UIEdgeInsets(top: 7.0, left: 7.0, bottom: 7.0, right: 7.0)
        settingsBtn.setImage(UIImage(named: "ic_nav_disclose"), for: .normal)
        settingsBtn.addTarget(self, action: #selector(settingsBtnTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItems = [UIBarButtonItem(customView: settingsBtn)]
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
            return AccountsRepository.shared.ephAccounts[indexPath.row]
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

    func onAbout() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogAboutViewController") as? DialogAboutViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            present(vc, animated: false, completion: nil)
        }
    }
    func onAppSettings() {
        let storyboard = UIStoryboard(name: "AppSettings", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AppSettingsViewController") as? AppSettingsViewController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    @objc func settingsBtnTapped() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {
            vc.delegate = self
            vc.viewModel = DialogListViewModel(title: "Options".localized, type: .walletListPrefs, items: WalletListPrefs.getItems())
            vc.modalPresentationStyle = .overFullScreen
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

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let renameTitle = "id_rename".localized
        let deleteTitle = "id_delete".localized

        let renameRowAction = UIContextualAction(style: .normal, title: renameTitle) { [weak self] (_, _, completed) -> Void in
            if let account = self?.getAccountFromTableView(indexPath) {
                self?.walletRename(account.id)
            }
            completed(true)
        }
        let pencilImage = UIImage(named: "ic_wallet_list_pencil")?.withRenderingMode(.alwaysOriginal)
        pencilImage?.setSwipeTag(AccessibilityIds.CommonElements.ctaSwipeEditAction)
        renameRowAction.image = pencilImage

        let deleteRowAction = UIContextualAction(style: .destructive, title: deleteTitle) { [weak self] (_, _, completed) -> Void in
            if let account = self?.getAccountFromTableView(indexPath) {
                self?.walletDelete(account.id)
            }
            completed(true)
        }
        let binImage = UIImage(named: "ic_wallet_list_bin")?.withRenderingMode(.alwaysOriginal)
        binImage?.setSwipeTag(AccessibilityIds.CommonElements.ctaSwipeDeleteAction)
        deleteRowAction.image = binImage

        let configuration = UISwipeActionsConfiguration(actions: [deleteRowAction, renameRowAction])
        configuration.performsFirstActionWithFullSwipe = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self, let cell = tableView.cellForRow(at: indexPath) else { return }

            let searchRoot: UIView = {
                if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
                   let window = scene.windows.first(where: { $0.isKeyWindow }) {
                    return window
                }
                return self.view
            }()

            // Candidate views are those overlapping the cell's vertical area and located to the right of the cell
            let candidates = searchRoot.allSubviews().filter { cand in
                let candFrameInTable = cand.convert(cand.bounds, to: tableView)
                // overlapping vertically
                let verticalOverlap = candFrameInTable.minY < cell.frame.maxY && candFrameInTable.maxY > cell.frame.minY
                // positioned to the right of cell's content area (swipe actions appear beside the cell)
                let toTheRight = candFrameInTable.minX >= cell.frame.maxX - 1
                return verticalOverlap && toTheRight
            }
            var attached = 0
            for view in candidates {
                // try finding a tagged image view inside the candidate first
                let imageViews = view.allSubviews().compactMap({ $0 as? UIImageView })
                var foundTag: String?
                for iv in imageViews {
                    if let tag = iv.image?.swipeTag() {
                        foundTag = tag
                        break
                    }
                }
                if let tag = foundTag {
                    view.isAccessibilityElement = true
                    view.accessibilityIdentifier = tag
                    view.accessibilityLabel = tag
                    print("Tagged: \(tag)")
                    attached += 1
                }
            }
        }
        return configuration
    }
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
            return AccountsRepository.shared.ephAccounts.count
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
                               onTap: { [weak self] indexPath in self?.onTapOverview(indexPath) })
                cell.selectionStyle = .none
                cell.buttonView.accessibilityIdentifier = AccessibilityIds.CommonElements.cellWalletSelect(indexPath.row)
                return cell
            }
        case .ephWallet:
            let account = AccountsRepository.shared.ephAccounts[indexPath.row]
            if let cell = tableView.dequeueReusableCell(withIdentifier: "WalletListCell") as? WalletListCell {
                cell.configure(item: account,
                               indexPath: indexPath,
                               onTap: { [weak self] indexPath in self?.onTapOverview(indexPath) })
                cell.selectionStyle = .none
                cell.buttonView.accessibilityIdentifier = AccessibilityIds.CommonElements.cellWalletSelect(indexPath.row)
                return cell
            }
        case .hwWallet:
            let account = AccountsRepository.shared.hwVisibleAccounts[indexPath.row]
            if let cell = tableView.dequeueReusableCell(withIdentifier: "WalletListCell") as? WalletListCell {
                cell.configure(
                    item: account,
                    indexPath: indexPath,
                    onTap: { [weak self] indexPath in self?.onTapOverview(indexPath) })
                cell.selectionStyle = .none
                cell.buttonView.accessibilityIdentifier = AccessibilityIds.CommonElements.cellWalletSelect(indexPath.row)
                return cell
            }
        default:
            break
        }

        return UITableViewCell()
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.1
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
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
                self.startLoader(message: "id_removing_wallet".localized)
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

extension HomeViewController: DialogListViewControllerDelegate {
    func didSwitchAtIndex(index: Int, isOn: Bool, type: DialogType) {}

    func didSelectIndex(_ index: Int, with type: DialogType) {
        switch type {
        case .walletListPrefs:
            switch index {
            case 0:
                onAppSettings()
            case 1:
                onAbout()
            default:
                break
            }
        default:
            break
        }
    }
}
