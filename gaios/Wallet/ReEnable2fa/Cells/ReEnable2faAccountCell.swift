import UIKit
import gdk
import core

class ReEnable2faAccountCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var btnDisclose: UIButton!
    @IBOutlet weak var imgMS: UIImageView!
    @IBOutlet weak var imgSS: UIImageView!
    @IBOutlet weak var imgLight: UIImageView!
    @IBOutlet weak var lblType: UILabel!
    @IBOutlet weak var lblName: UILabel!
    @IBOutlet weak var lblHint: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        bg.cornerRadius = 5.0
        btnDisclose.isUserInteractionEnabled = false
        btnDisclose.backgroundColor = UIColor.gGreenMatrix()
        btnDisclose.cornerRadius = 4.0
        lblName.setStyle(.txtBigger)
        [lblHint, lblType].forEach {
            $0.setStyle(.txtCard)
//            $0.textColor = UIColor.gW60()
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    class var identifier: String { return String(describing: self) }

    override func prepareForReuse() {
        super.prepareForReuse()

    }

    func configure(subaccount: WalletItem) {
        lblType.text = subaccount.type.path.uppercased()
        lblName.text = subaccount.name
        lblHint.text = "Redeposit Expired 2FA Coins"
    }
}
