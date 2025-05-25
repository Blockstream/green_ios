import UIKit
import core

class WalletListCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var iconSecurityType: UIImageView!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var buttonView: UIButton!
    @IBOutlet weak var iconArrow: UIImageView!

    var onLongpress: ((IndexPath) -> Void)?
    var onTap: ((IndexPath) -> Void)?
    var indexPath: IndexPath?

    var account: Account?

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)

        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(onLongPressed))
        buttonView.addGestureRecognizer(longPressRecognizer)
    }

    override func prepareForReuse() {
        icon.image = UIImage()
        lblTitle.text = ""
        lblHint.text = ""
        iconSecurityType.image = UIImage()
    }

    func configure(item: Account,
                   indexPath: IndexPath,
                   onLongpress: ((IndexPath) -> Void)? = nil,
                   onTap: ((IndexPath) -> Void)? = nil
    ) {
        lblTitle.text = item.name
        lblHint.text = ""
        lblTitle.setStyle(.txtBigger)
        lblHint.setStyle(.txtSmaller)
        self.account = item
        let img: UIImage? = {
            if item.isWatchonly {
                return UIImage(named: "ic_eye_flat")
            } else if item.gdkNetwork.mainnet {
                return UIImage(named: "ic_wallet")
            } else {
                return UIImage(named: "ic_wallet_testnet")
            }
        }()
        self.icon.image = img!.maskWithColor(color: .white)
        self.iconSecurityType.image = UIImage() // UIImage(named: "ic_keys_invert")!

        lblHint.isHidden = !(item.isEphemeral || item.isHW)
        if let ephemeralId = item.ephemeralId {
            lblHint.text = "BIP39 #\( ephemeralId )"
        }
        self.indexPath = indexPath
        self.onTap = onTap
        self.onLongpress = onLongpress
    }

    @objc func onLongPressed(sender: UILongPressGestureRecognizer) {
        if sender.state == UIGestureRecognizer.State.began {
            if let indexPath = indexPath {
                onLongpress?(indexPath)
            }
        }
    }

    @IBAction func btnTap(_ sender: Any) {
        if let indexPath = indexPath {
            bg.pressAnimate {
                self.onTap?(indexPath)
            }
        }
    }
}
