import UIKit

class WalletTabBar: UITabBar {

    override func awakeFromNib() {
        super.awakeFromNib()

        self.layer.shadowColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1).cgColor
        self.layer.shadowOffset = CGSize(width: 0.0, height: 2.0)
        self.layer.shadowRadius = 4.0
        self.layer.shadowOpacity = 0.4
//        self.layer.masksToBounds = false
    }
}
