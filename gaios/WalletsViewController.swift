import Foundation
import UIKit
import PromiseKit

class WalletsViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {

    var wallets = [WalletItem]()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = NSLocalizedString("id_wallets", comment: "")
        let cellNib = UINib(nibName: "WalletCardView", bundle: nil)
        self.collectionView!.register(cellNib, forCellWithReuseIdentifier: "cell")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AccountStore.shared.getWallets(cached: true).done { wallets in
            self.wallets = wallets
            self.collectionView?.reloadData()
        }
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return wallets.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell",
                                                      for: indexPath) as! WalletCardView
        let wallet = wallets[indexPath.row]
        cell.balance.text = String.formatBtc(satoshi: wallet.satoshi)
        cell.walletName.text = wallet.localizedName()
        cell.networkImage.image = UIImage.init(named: getNetwork() == "Mainnet".lowercased() ? "btc" : "btc_testnet")

        guard let res = try? getSession().convertAmount(input: ["satoshi": wallet.satoshi]) else { return cell }
        cell.balanceFiat.text = String(format: "≈ %@ %@", (res!["fiat"] as? String)!, getGAService().getSettings()!.getCurrency())
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let padding = 22
        let width = self.view.frame.width - CGFloat(padding)
        return CGSize(width: width, height: 180)
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let wallet = wallets[indexPath.row]
        self.performSegue(withIdentifier: "account", sender: wallet)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? TransactionsController {
            guard let wallet = sender as? WalletItem else { return }
            nextController.presentingWallet = wallet
            Guarantee().map {
                try! getSession().setCurrentSubaccount(subaccount: wallet.pointer)
            }
        }
    }
}
