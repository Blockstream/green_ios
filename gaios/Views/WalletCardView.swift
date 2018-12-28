import Foundation
import UIKit

class WalletCardView: UICollectionViewCell {

    @IBOutlet weak var balance: UILabel!
    @IBOutlet weak var balanceFiat: UILabel!
    @IBOutlet weak var walletName: UILabel!
    @IBOutlet weak var networkImage: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        self.contentView.borderColor = UIColor.customMatrixGreen()
        self.contentView.borderWidth = 2
        self.contentView.cornerRadius = 16
    }
}
