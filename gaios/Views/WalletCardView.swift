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

        let gradient = CAGradientLayer()
        gradient.colors = [UIColor.cardDark().cgColor, UIColor.cardMedium().cgColor, UIColor.cardLight().cgColor]
        gradient.locations = [0.0, 0.5, 1.0]
        gradient.startPoint = CGPoint(x: 0.0, y: 1.0)
        gradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        gradient.frame = self.contentView.bounds
        gradient.borderWidth = 2
        gradient.cornerRadius = 8
        gradient.borderColor = UIColor.customTitaniumDark().cgColor
        gradient.masksToBounds = true
     
        let bgView = UIView.init(frame: self.contentView.bounds)
        bgView.layer.insertSublayer(gradient, at: 0)
        self.backgroundView = bgView
    }
}
