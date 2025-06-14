import UIKit
import core

class BalanceCell: UITableViewCell {

    @IBOutlet weak var lblBalanceTitle: UILabel!
    @IBOutlet weak var lblBalanceValue: UILabel!
    @IBOutlet weak var lblBalanceFiat: UILabel!
    @IBOutlet weak var btnAssets: UIButton!
    @IBOutlet weak var iconsView: UIView!
    @IBOutlet weak var iconsStack: UIStackView!
    @IBOutlet weak var iconsStackWidth: NSLayoutConstraint!
    @IBOutlet weak var btnEye: UIButton!
    @IBOutlet weak var assetsBox: UIView!
    @IBOutlet weak var loader: UIActivityIndicatorView!
    @IBOutlet weak var btnExchange: UIButton!
    @IBOutlet weak var btnExchangeAlign: NSLayoutConstraint!
    @IBOutlet weak var lblLoadingAssets: UILabel!

    private var model: BalanceCellModel?
    private var onAssets: (() -> Void)?
    private var onConvert: (() -> Void)?
    private var onHide: ((Bool) -> Void)?
    private var onExchange: (() -> Void)?
    private let iconW: CGFloat = 20.0
    private var hideBalance = false

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        lblBalanceTitle.text = "Total Bitcoin Balance".localized
        btnExchange.setImage(UIImage(named: "ic_coins_exchange")?.maskWithColor(color: .white.withAlphaComponent(0.4)), for: .normal)
        lblLoadingAssets.text = "id_loading_assets".localized
        [lblBalanceTitle, lblBalanceFiat].forEach { $0?.setStyle(.txtSectionHeader) }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(model: BalanceCellModel?,
                   hideBalance: Bool,
                   hideBtnExchange: Bool,
                   onHide: ((Bool) -> Void)?,
                   onAssets: (() -> Void)?,
                   onConvert: (() -> Void)?,
                   onExchange: (() -> Void)?) {
        self.hideBalance = hideBalance
        self.model = model
        lblBalanceValue.text = ""
        lblBalanceFiat.text = ""
        btnExchange.isHidden = hideBtnExchange

        let assetsCount = model?.cachedBalance.nonZeroAmounts().count ?? 0
        assetsBox.isHidden = true // assetsCount < 2

        let uLineAttr = [NSAttributedString.Key.underlineStyle: NSUnderlineStyle.thick.rawValue]
        let str = NSAttributedString(string: String(format: "id_d_assets_in_total".localized, assetsCount), attributes: uLineAttr)
        btnAssets.setAttributedTitle(str, for: .normal)
        self.onAssets = onAssets
        self.onHide = onHide
        self.onConvert = onConvert
        self.onExchange = onExchange
        refreshVisibility()
        for v in iconsStack.subviews {
            v.removeFromSuperview()
        }
        let assets = model?.cachedBalance
        var icons: [UIImage] = []
        for asset in assets?.ids ?? [] {
            if let icon = assets?.image(for: asset) {
                if icons.count > 0 {
                    if icon != icons.last {
                        icons.append(icon)
                    }
                } else {
                    icons.append(icon)
                }
            }
        }
        icons = Array(icons.prefix(10))
        iconsStackWidth.constant = CGFloat(icons.count) * iconW - CGFloat(icons.count - 1) * 5.0
        setImages(icons)
        iconsView.isHidden = false // !showAccounts || !gdkNetwork.liquid

        // future usage
        lblLoadingAssets.isHidden = true
    }

    func setImages(_ images: [UIImage]) {
        for img in images {
            let imageView = UIImageView()
            imageView.image = img
            iconsStack.addArrangedSubview(imageView)
        }
    }

    func refreshVisibility() {
        model == nil ? loader.startAnimating() : loader.stopAnimating()
        btnExchangeAlign.constant = model == nil ? 0 : -8
        lblBalanceValue.isHidden = model == nil
        lblBalanceFiat.isHidden = true // model == nil
        if hideBalance {
            lblBalanceValue.attributedText = Common.obfuscate(color: .white, size: 24, length: 5)
            lblBalanceFiat.attributedText = Common.obfuscate(color: .gray, size: 12, length: 5)
            btnEye.setImage(UIImage(named: "ic_eye_closed"), for: .normal)
        } else {
            lblBalanceValue.text = self.model?.value
            lblBalanceFiat.text = self.model?.valueChange
            btnEye.setImage(UIImage(named: "ic_eye_flat"), for: .normal)
        }
    }

    @IBAction func onBalanceTap(_ sender: Any) {
        AnalyticsManager.shared.convertBalance(account: AccountsRepository.shared.current)
        onConvert?()
    }

    @IBAction func btnEye(_ sender: Any) {
        if !hideBalance { AnalyticsManager.shared.hideAmount(account: AccountsRepository.shared.current) }
        hideBalance = !hideBalance
        onHide?(hideBalance)
        refreshVisibility()
    }

    @IBAction func btnAssets(_ sender: Any) {
        onAssets?()
    }

    @IBAction func onExchange(_ sender: Any) {
        onExchange?()
    }
}
