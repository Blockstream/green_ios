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
    @IBOutlet weak var sendImage: UIImageView!
    @IBOutlet weak var receiveImage: UIImageView!
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var unit: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        self.sendLabel.text = NSLocalizedString("id_send", comment: "").uppercased()
        self.receiveLabel.text = NSLocalizedString("id_receive", comment: "").uppercased()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let gradient = CAGradientLayer()
        gradient.colors = [UIColor.cardDark().cgColor, UIColor.cardMedium().cgColor, UIColor.cardLight().cgColor]
        gradient.locations = [0.0, 0.5, 1.0]
        gradient.startPoint = CGPoint(x: 0.0, y: 1.0)
        gradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        gradient.frame = backgroundView.bounds
        backgroundView.layer.insertSublayer(gradient, at: 0)
    }
}
