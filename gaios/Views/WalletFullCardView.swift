import Foundation
import UIKit

class WalletFullCardView: UIView {

    @IBOutlet weak var walletName: UILabel!
    @IBOutlet weak var balance: UILabel!
    @IBOutlet weak var sendView: UIView!
    @IBOutlet weak var receiveView: UIView!
    @IBOutlet weak var actionsView: UIStackView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.borderColor = UIColor.customMatrixGreen()
        self.borderWidth = 2
        self.cornerRadius = 16
    }
}
