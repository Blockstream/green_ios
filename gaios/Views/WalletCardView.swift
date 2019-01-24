import Foundation
import UIKit

class WalletCardView: UICollectionViewCell {

    @IBOutlet weak var balance: UILabel!
    @IBOutlet weak var balanceFiat: UILabel!
    @IBOutlet weak var walletName: UILabel!
    @IBOutlet weak var networkImage: UIImageView!
    @IBOutlet weak var unit: UILabel!
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let bgView = UIView.init(frame: self.contentView.bounds)
        bgView.applyCardGradient()
        backgroundView = bgView
    }
}
