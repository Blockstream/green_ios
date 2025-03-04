import UIKit
import gdk

enum TabHomeSection: Int, CaseIterable {
    case header
    case balance
    case assets
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
}
enum TabSettingsSection: Int, CaseIterable {
    case header
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
        let storyboard = UIStoryboard(name: "BuyFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "BuyViewController") as? BuyViewController {
            guard let model = walletModel.accountCellModels[safe: 0] else { return }
            var account: WalletItem? = model.account
            if account?.networkType.liquid ?? false {
                account = walletModel.wm?.bitcoinSubaccounts.first
            }
            if let account {
                vc.viewModel = BuyViewModel(account: account, side: .buy)
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    func sendScreen(_ walletModel: WalletModel) {
        guard let model = walletModel.accountCellModels[safe: 0] else { return }
        let sendAddressInputViewModel = SendAddressInputViewModel(
            input: nil,
            preferredAccount: model.account,
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
            guard let model = walletModel.accountCellModels[safe: 0] else { return }
            vc.viewModel = ReceiveViewModel(account: model.account,
                                            accounts: walletModel.subaccounts)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
