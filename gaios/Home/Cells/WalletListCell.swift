import UIKit

class WalletListCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var iconSecurityType: UIImageView!
    @IBOutlet weak var circleImageView: UIImageView!
    @IBOutlet weak var iconPassphrase: UIImageView!
    @IBOutlet weak var iconHW: UIImageView!
    @IBOutlet weak var lblHint: UILabel!

    @IBOutlet weak var lblOverviewTitle: UILabel!
    @IBOutlet weak var lblShortcutTitle: UILabel!
    @IBOutlet weak var shortcutStack: UIStackView!
    @IBOutlet weak var circleImageOverview: UIImageView!
    @IBOutlet weak var circleImageShortcut: UIImageView!
    @IBOutlet weak var shortcutView: UIView!

    var onLongpress: (() -> Void)?

    var onTap: ((IndexPath) -> Void)?
    var onTapOverview: ((IndexPath) -> Void)?
    var onTapLightShort: ((IndexPath) -> Void)?
    var indexPath: IndexPath?

    var hasShortcut = false
    var account: Account?

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.cornerRadius = 7.0

        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressed))
        self.addGestureRecognizer(longPressRecognizer)

        shortcutView.layer.cornerRadius = 7.0
        shortcutView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    override func prepareForReuse() {
        icon.image = UIImage()
        lblTitle.text = ""
        lblHint.text = ""
        iconSecurityType.image = UIImage()
        iconPassphrase.image = UIImage()
        iconHW.image = UIImage()
    }

    func configure(item: Account,
                   isOverviewSelected: Bool = false,
                   isLightningSelected: Bool = false,
                   indexPath: IndexPath,
                   onLongpress: (() -> Void)? = nil,
                   onTap: ((IndexPath) -> Void)? = nil,
                   onTapOverview: ((IndexPath) -> Void)? = nil,
                   onTapLightShort: ((IndexPath) -> Void)? = nil
    ) {
        lblTitle.text = item.name
        lblHint.text = ""
        [lblTitle, lblOverviewTitle, lblShortcutTitle].forEach{
            $0.setStyle(.txtBigger)
        }
        lblHint.setStyle(.txtSmaller)
        self.hasShortcut = item.getDerivedLightningAccount() != nil
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
            iconPassphrase.image = UIImage(named: "ic_passphrase")!
        }
        if item.isHW {
            if item.isJade {
                iconHW.image = UIImage(named: "ic_hww_jade")!
            }
            if item.isLedger {
                iconHW.image = UIImage(named: "ic_hww_ledger")!
            }
        }
        iconPassphrase.isHidden = !item.isEphemeral
        iconHW.isHidden = !item.isHW
        self.onLongpress = onLongpress

        shortcutStack.subviews.forEach { $0.isHidden = true }
        if hasShortcut == true {
            shortcutStack.subviews.forEach { $0.isHidden = false }
        }
        circleImageView.isHidden = hasShortcut || !isOverviewSelected
        circleImageOverview.isHidden = !hasShortcut || !isOverviewSelected
        circleImageShortcut.isHidden = !hasShortcut || !isLightningSelected
        lblOverviewTitle.text = "Wallet Overview".localized
        lblShortcutTitle.text = "Lightning Account".localized

        self.indexPath = indexPath
        self.onTap = onTap
        self.onTapOverview = onTapOverview
        self.onTapLightShort = onTapLightShort
    }

    @objc func longPressed(sender: UILongPressGestureRecognizer) {

        if sender.state == UIGestureRecognizer.State.began {
            onLongpress?()
        }
    }

    @IBAction func btnTap(_ sender: Any) {
        if let indexPath = indexPath {
            onTap?(indexPath)
        }
    }
    
    @IBAction func onTapOverview(_ sender: Any) {
        if let indexPath = indexPath {
            onTapOverview?(indexPath)
        }
    }
    
    @IBAction func btnTapLightShort(_ sender: Any) {
        if let indexPath = indexPath {
            onTapLightShort?(indexPath)
        }
    }
}
