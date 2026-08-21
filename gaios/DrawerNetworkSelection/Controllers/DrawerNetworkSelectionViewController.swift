import Foundation
import UIKit
import core

protocol DrawerNetworkSelectionDelegate: AnyObject {
    func didSelectWallet(wallet: Wallet)
    func didSelectAddWallet()
    func didSelectSettings()
    func didSelectAbout()
}

class DrawerNetworkSelectionViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var btnSettings: UIButton!
    @IBOutlet weak var newWalletView: UIView!
    @IBOutlet weak var lblNewWallet: UILabel!
    @IBOutlet weak var btnAddWallet: UIButton!
    @IBOutlet weak var btnClose: UIButton!

    var onSelection: ((Wallet) -> Void)?
    weak var delegate: DrawerNetworkSelectionDelegate?

    var headerH: CGFloat = 44.0
    var footerH: CGFloat = 54.0
    var isAnimating = false
    private let priceChartViewModel = PriceChartViewModel()
    private var activeToken: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        ["WalletListCell", "PriceChartCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
        view.accessibilityIdentifier = AccessibilityIds.DrawerScreen.view
        btnAddWallet.accessibilityIdentifier = AccessibilityIds.DrawerScreen.btnSetUpNewWallet
        btnClose.accessibilityIdentifier = AccessibilityIds.DrawerScreen.btnBack
        refreshPriceChart()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        activeToken = NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: view.window?.windowScene,
            queue: .main,
            using: sceneDidActivate
        )
        animateShortcut()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if let token = activeToken {
            NotificationCenter.default.removeObserver(token)
            activeToken = nil
        }
    }

    func setContent() {
        lblNewWallet.text = "id_set_up_a_new_wallet".localized
    }

    func setStyle() {
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        view.backgroundColor = UIColor.gBlackBg()
        tableView.backgroundColor = UIColor.gBlackBg()
        newWalletView.setStyle(CardStyle.defaultStyle)
    }

    func getWalletFromTableView(_ indexPath: IndexPath) -> Wallet? {
        switch HomeSection(rawValue: indexPath.section) {
        case .swWallet:
            return WalletsStorage.shared.sws[indexPath.row]
        case .ephWallet:
            return WalletsStorage.shared.ephs[indexPath.row]
        case .hwWallet:
            return WalletsStorage.shared.hwsVisible[indexPath.row]
        default:
            return nil
        }
    }

    func onTap(_ indexPath: IndexPath) {
        onTapOverview(indexPath)
    }

    func onTapOverview(_ indexPath: IndexPath) {
        if let wallet = getWalletFromTableView(indexPath) {
            self.delegate?.didSelectWallet(wallet: wallet)
        }
    }

    @IBAction func btnAddWallet(_ sender: Any) {
        newWalletView.pressAnimate {
            self.delegate?.didSelectAddWallet()
        }
    }

    @IBAction func btnSettings(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {
            vc.delegate = self
            vc.viewModel = DialogListViewModel(title: "Options".localized, type: .walletListPrefs, items: WalletListPrefs.getItems())
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @IBAction func btnClose(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    private func refreshPriceChart() {
        Task { [weak self] in
            guard let self else { return }
            await self.priceChartViewModel.load()
            await MainActor.run {
                self.tableView.reloadData()
            }
        }
    }

    @objc private func sceneDidActivate(_ notification: Notification) {
        refreshPriceChart()
    }

}

extension DrawerNetworkSelectionViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return HomeSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch HomeSection(rawValue: section) {
        case .swWallet:
            return WalletsStorage.shared.sws.count
        case .ephWallet:
            return WalletsStorage.shared.ephs.count
        case .hwWallet:
            return WalletsStorage.shared.hwsVisible.count
        case .chart:
            return 1
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch HomeSection(rawValue: indexPath.section) {
        case .swWallet:
            let wallet = WalletsStorage.shared.sws[indexPath.row]
            if let cell = tableView.dequeueReusableCell(withIdentifier: "WalletListCell") as? WalletListCell {
                cell.configure(item: wallet,
                               indexPath: indexPath,
                               onTap: { [weak self] indexPath in self?.onTap(indexPath) }
                )
                cell.buttonView.accessibilityIdentifier = AccessibilityIds.CommonElements.cellWalletSelect(indexPath.row)
                cell.selectionStyle = .none
                return cell
            }
        case .ephWallet:
            let wallet = WalletsStorage.shared.ephs[indexPath.row]
            if let cell = tableView.dequeueReusableCell(withIdentifier: "WalletListCell") as? WalletListCell {
                cell.configure(item: wallet,
                               indexPath: indexPath,
                               onTap: { [weak self] indexPath in self?.onTap(indexPath) }
                )
                cell.selectionStyle = .none
                cell.buttonView.accessibilityIdentifier = AccessibilityIds.CommonElements.cellWalletSelect(indexPath.row)
                return cell
            }
        case .hwWallet:
            let wallet = WalletsStorage.shared.hwsVisible[indexPath.row]
            if let cell = tableView.dequeueReusableCell(withIdentifier: "WalletListCell") as? WalletListCell {
                cell.configure(item: wallet,
                               indexPath: indexPath,
                               onTap: { [weak self] indexPath in self?.onTap(indexPath) }
                )
                cell.selectionStyle = .none
                cell.buttonView.accessibilityIdentifier = AccessibilityIds.CommonElements.cellWalletSelect(indexPath.row)
                return cell
            }
        case .chart:
            if let cell = tableView.dequeueReusableCell(withIdentifier: PriceChartCell.identifier, for: indexPath) as? PriceChartCell {
                cell.configure(
                    priceChartViewModel.cellModel(),
                    timeFrame: priceChartViewModel.timeFrame,
                    onBuy: nil,
                    onNewFrame: { [weak self] timeFrame in
                        self?.priceChartViewModel.timeFrame = timeFrame
                    })
                cell.selectionStyle = .none
                return cell
            }
        default:
            break
        }

        return UITableViewCell()
    }

    func isOverviewSelected(_ wallet: Wallet) -> Bool {
        WalletsRepository.shared
            .get(for: wallet.id)?.activeNetworkIds.count ?? 0 > 0
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch HomeSection(rawValue: section) {
        case .swWallet:
            return headerH
        case .chart:
            return headerH
        default:
            return 0.1
        }
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch HomeSection(rawValue: section) {
        case .swWallet:
            return headerView("id_my_wallets".localized)
        case .chart:
            return headerView("id_bitcoin_price".localized)
        default:
            return nil
        }
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

    }
}

extension DrawerNetworkSelectionViewController {
    func headerView(_ txt: String) -> UIView {
        guard let tView = tableView else { return UIView(frame: .zero) }
        let section = UIView(frame: CGRect(x: 0, y: 0, width: tView.frame.width, height: headerH))
        section.backgroundColor = UIColor.gBlackBg()
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
            title.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -25)
        ])
        return section
    }
}

extension DrawerNetworkSelectionViewController: UIScrollViewDelegate {
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate {
            animateShortcut()
        }
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        animateShortcut()
    }

    func animateShortcut() {

        for cell in tableView.visibleCells {
            if let c = cell as? WalletListCell,
               c.wallet?.id == DrawerAnimationManager.shared.walletId {
                DrawerAnimationManager.shared.walletId = nil
            }
        }
    }
}
extension DrawerNetworkSelectionViewController: DialogListViewControllerDelegate {
    func didSwitchAtIndex(index: Int, isOn: Bool, type: DialogType) {}

    func didSelectIndex(_ index: Int, with type: DialogType) {
        switch type {
        case .walletListPrefs:
            switch index {
            case 0:
                delegate?.didSelectSettings()
            case 1:
                delegate?.didSelectAbout()
            default:
                break
            }
        default:
            break
        }
    }
}
