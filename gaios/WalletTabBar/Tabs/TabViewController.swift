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
    case jade
    case backup
    case unlock
    case recovery
}
enum TabSettingsSection: Int, CaseIterable {
    case header
    case general
    case wallet
    case twoFactor
    case about
}

class TabViewController: UIViewController {

    var sectionHeaderH: CGFloat = 54.0
    var footerH: CGFloat = 54.0

    var walletModel: WalletModel {
        // swiftlint:disable force_cast
        let mainTab = parent as! WalletTabBarViewController
        return mainTab.walletModel
    }

    var walletTab: WalletTabBarViewController {
        // swiftlint:disable force_cast
        parent as! WalletTabBarViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
extension TabViewController {
    func buyScreen(_ walletModel: WalletModel) {
        let storyboard = UIStoryboard(name: "BuyBTCFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "BuyBTCViewController") as? BuyBTCViewController {
            if var accounts = walletModel.wm?.bitcoinSubaccounts, let account = walletModel.wm?.bitcoinSubaccounts.first {
                if let lightningSubaccount = walletModel.wm?.lightningSubaccount {
                    // RE-Enable once validation is ready
                    // accounts.append(lightningSubaccount)
                }
                vc.viewModel = BuyBTCViewModel(account: account,
                                               accounts: accounts,
                                               currency: walletModel.currency,
                                               hideBalance: walletModel.hideBalance)
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    func sendScreen(_ walletModel: WalletModel) {
        let sendAddressInputViewModel = SendAddressInputViewModel(
            input: nil,
            preferredAccount: walletModel.wm?.bitcoinSubaccounts.first,
            txType: walletModel.isSweepEnabled() ? .sweep : .transaction)

        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendAddressInputViewController") as? SendAddressInputViewController {
            vc.viewModel = sendAddressInputViewModel
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func txScreen(_ tx: Transaction) {
        let storyboard = UIStoryboard(name: "TxDetails", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "TxDetailsViewController") as? TxDetailsViewController, let wallet = tx.subaccountItem {
            vc.vm = TxDetailsViewModel(wallet: wallet, transaction: tx)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func receiveScreen(_ walletModel: WalletModel) {
        let storyboard = UIStoryboard(name: "Wallet", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ReceiveViewController") as? ReceiveViewController {
            if let subaccount = walletModel.wm?.bitcoinSubaccounts.first {
                vc.viewModel = ReceiveViewModel(account: subaccount,
                                                accounts: walletModel.subaccounts)
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    func accountsScreen(model: DialogAccountsViewModel) {
        let storyboard = UIStoryboard(name: "WalletTab", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogAccountsViewController") as? DialogAccountsViewController {
            vc.viewModel = model
            vc.modalPresentationStyle = .overFullScreen
            UIApplication.shared.delegate?.window??.rootViewController?.present(vc, animated: false, completion: nil)
        }
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
