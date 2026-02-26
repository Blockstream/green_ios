import UIKit
import gdk
import core

enum TabHomeSection: Int, CaseIterable {
    case header
    case balance
    case backup
    case card
    case assets
    case chart
    case promo
}
enum TabTransactSection: Int, CaseIterable {
    case header
    case balance
    case actions
    case transactions
}
enum TabSecuritySection: Int, CaseIterable {
    case header
    case level
    case watchonly
    case jade
    case backup
    case unlock
    case recovery
}
enum TabSettingsSection: Int, CaseIterable {
    case header
    case wallet
    case account
    case about
    case support
}
class TabViewController: UIViewController {
    var sectionHeaderH: CGFloat = 54.0
    var footerH: CGFloat = 54.0

    var walletTab: WalletTabBarViewController {
        // swiftlint:disable force_cast
        parent as! WalletTabBarViewController
    }

    func checkUKRegion() -> Bool {
        return Locale.current.region?.identifier == "GB"
    }
    func getCountlyRemoteConfigEnableBuyIosUk() -> Bool {
        return AnalyticsManager.shared.getRemoteConfigValue(key: AnalyticsManager.countlyRemoteConfigEnableBuyIosUk) as? Bool ?? false
    }
    func getBitcoinSubaccounts() -> [WalletItem] {
        WalletManager.current?.bitcoinSubaccounts.sorted(by: { $0.btc ?? 0 > $1.btc ?? 0 }) ?? []
    }
    func buyScreen(currency: String, hideBalance: Bool) {
        AnalyticsManager.shared.buyInitiate(account: AccountsRepository.shared.current)
        if !getCountlyRemoteConfigEnableBuyIosUk() && checkUKRegion() {
            showAlert(title: "id_buy_btc".localized, message: "id_feature_unavailable_in_the_uk".localized)
            return
        }
        if getBitcoinSubaccounts().isEmpty {
            showAlert(title: "id_buy_btc".localized, message: "id_feature_unavailable_for_liquid".localized)
            return
        }
        let storyboard = UIStoryboard(name: "BuyBTCFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "BuyBTCViewController") as? BuyBTCViewController {
            vc.viewModel = BuyBTCViewModel(
                currency: currency,
                hideBalance: hideBalance)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    private var activeSendCoordinator: SendCoordinator?
    func sendScreen(walletDataModel: WalletDataModel, input: String?) {
        if let nav = navigationController {
            activeSendCoordinator = SendCoordinator(nav: nav, wallet: walletDataModel, mainAccount: walletTab.mainAccount) { [weak self] in
                nav.popToRootViewController(animated: true)
                self?.activeSendCoordinator = nil
            }
            activeSendCoordinator?.start(input: input, subaccount: nil, assetId: nil)
        }
    }
    func receiveScreen() {
        let storyboard = UIStoryboard(name: "Wallet", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ReceiveViewController") as? ReceiveViewController {
            vc.viewModel = ReceiveViewModel()
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func accountsScreen(model: DialogAccountsViewModel) {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "DialogAccountsViewController") { coder in
            DialogAccountsViewController(coder: coder, viewModel: model)
        }
        vc.modalPresentationStyle = .overFullScreen
        present(vc, animated: true)
    }
    func securityCompareScreen() {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogCompareSecurityViewController") as? DialogCompareSecurityViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            UIApplication.shared.delegate?.window??.rootViewController?.present(vc, animated: false, completion: nil)
        }
    }
}
extension TabViewController: DialogCompareSecurityViewControllerDelegate {
    func onHardwareTap(_ action: CompareSecurityAction) {
        switch action {
        case .setupHardware:
            let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
            if let vc = hwFlow.instantiateViewController(withIdentifier: "WelcomeJadeViewController") as? WelcomeJadeViewController {
                navigationController?.pushViewController(vc, animated: true)
                AnalyticsManager.shared.hwwWallet()
            }
        case .buyJade:
            SafeNavigationManager.shared.navigate( ExternalUrls.buyJadePlus )
        case .none:
            break
        }
    }
}
