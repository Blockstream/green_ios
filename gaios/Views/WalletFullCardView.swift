import Foundation
import UIKit

class WalletFullCardView: UIView {

    @IBOutlet weak var walletName: UILabel!
    @IBOutlet weak var balance: UILabel!
    @IBOutlet weak var balanceFiat: UILabel!
    @IBOutlet weak var sendView: UIView!
    @IBOutlet weak var receiveView: UIView!
    @IBOutlet weak var actionsView: UIStackView!
    @IBOutlet weak var sendLabel: UILabel!
    @IBOutlet weak var receiveLabel: UILabel!
    @IBOutlet weak var stackButton: UIButton!
    @IBOutlet weak var networkImage: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        self.borderColor = UIColor.customMatrixGreen()
        self.borderWidth = 2
        self.cornerRadius = 16
        self.sendLabel.text = NSLocalizedString("id_send", comment: "").uppercased()
        self.receiveLabel.text = NSLocalizedString("id_receive", comment: "").uppercased()
    }
}
