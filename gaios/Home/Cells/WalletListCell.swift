import UIKit
import core

class WalletListCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var buttonView: UIButton!
    @IBOutlet weak var iconArrow: UIImageView!
    @IBOutlet weak var iconWatchonly: UIImageView!

    var onTap: ((IndexPath) -> Void)?
    var indexPath: IndexPath?

    var account: Account?

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
    }
    override func prepareForReuse() {
        lblTitle.text = ""
        lblHint.text = ""
    }
    func configure(item: Account,
                   indexPath: IndexPath,
                   onTap: ((IndexPath) -> Void)? = nil
    ) {
        lblTitle.text = item.name
        lblHint.text = ""
        lblTitle.setStyle(.txtBigger)
        lblHint.setStyle(.txtCard)
        account = item
        lblHint.text = "id_mobile_wallet".localized
        if account?.isHW ?? false {
            lblHint.text = "id_hardware_wallet".localized
        }
        if account?.isWatchonly ?? false {
            lblHint.text = "id_watchonly".localized
        }
        if let ephemeralId = item.ephemeralId {
            lblHint.text = "BIP39 #\( ephemeralId )"
        }
        self.indexPath = indexPath
        self.onTap = onTap
        iconWatchonly.isHidden = true
    }

    @IBAction func btnTap(_ sender: Any) {
        if let indexPath = indexPath {
            bg.pressAnimate {
                self.onTap?(indexPath)
            }
        }
    }
}
