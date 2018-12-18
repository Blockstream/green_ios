import Foundation
import UIKit
import PromiseKit

class HomeViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {

    var wallets = [WalletItem]()

    override func viewDidLoad() {
        super.viewDidLoad()
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
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let padding = 22
        let width = self.view.frame.width - CGFloat(padding)
        return CGSize(width: width, height: 180)
    }
}
