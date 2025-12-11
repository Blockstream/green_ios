import UIKit
import core
import gdk

struct BalanceItem: Hashable {
    let satoshi: Int64?
    let assetId: String?
    
    var value: String? {
        guard let satoshi else { return nil }
        if let balance = Balance.fromSatoshi(satoshi, assetId: assetId ?? AssetInfo.btcId)?.toDenom() {
            if satoshi == 0 {
                return "0 \(balance.1)"
            } else {
                return "\(balance.0) \(balance.1)"
            }
        }
        return nil
    }
    var fiat: String? {
        guard let satoshi else { return nil }
        if let balance = Balance.fromSatoshi(satoshi, assetId: assetId ?? AssetInfo.btcId)?.toFiat() {
            if satoshi == 0 {
                return "0 \(balance.1)"
            } else {
                return "\(balance.0) \(balance.1)"
            }
        }
        return nil
    }
}

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

    private var item: BalanceItem?
    private var onAssets: (() -> Void)?
    private var onConvert: (() -> Void)?
    private var onHide: ((Bool) -> Void)?
    private var onExchange: (() -> Void)?
    private let iconW: CGFloat = 20.0
    private var hideBalance = false
    private var denomBalance = BalanceDisplayMode.denom

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        lblBalanceTitle.text = "id_total_bitcoin_balance".localized
        btnExchange.setImage(UIImage(named: "ic_coins_exchange")?.maskWithColor(color: .white.withAlphaComponent(0.4)), for: .normal)
        lblLoadingAssets.text = "id_loading_assets".localized
        [lblBalanceTitle, lblBalanceFiat].forEach { $0?.setStyle(.txtSectionHeader) }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(item: BalanceItem?,
                   denomBalance: BalanceDisplayMode,
                   hideBalance: Bool,
                   hideBtnExchange: Bool,
                   onHide: ((Bool) -> Void)?,
                   onAssets: (() -> Void)?,
                   onConvert: (() -> Void)?,
                   onExchange: (() -> Void)?) {
        self.item = item
        self.hideBalance = hideBalance
        self.denomBalance = denomBalance
        lblBalanceValue.text = ""
        lblBalanceFiat.text = ""
        btnExchange.isHidden = hideBtnExchange
        //let assetsCount = model?.cachedBalance.nonZeroAmounts().count ?? 0
        assetsBox.isHidden = true // assetsCount < 2
        btnAssets.isHidden = true
        iconsView.isHidden = false
        //let uLineAttr = [NSAttributedString.Key.underlineStyle: NSUnderlineStyle.thick.rawValue]
        //let str = NSAttributedString(string: String(format: "id_d_assets_in_total".localized, assetsCount), attributes: uLineAttr)
        //btnAssets.setAttributedTitle(str, for: .normal)
        self.onAssets = onAssets
        self.onHide = onHide
        self.onConvert = onConvert
        self.onExchange = onExchange
        refreshVisibility()// !showAccounts || !gdkNetwork.liquid

        // future usage
        lblLoadingAssets.isHidden = true
    }

    func refreshVisibility() {
        let idle = item?.value == nil
        if idle {
            loader.startAnimating()
        } else {
            loader.stopAnimating()
        }
        btnExchangeAlign.constant = idle ? 0 : -8
        lblBalanceValue.isHidden = idle
        lblBalanceFiat.isHidden = true // model == nil
        if hideBalance {
            lblBalanceValue.attributedText = Common.obfuscate(color: .white, size: 24, length: 5)
            lblBalanceFiat.attributedText = Common.obfuscate(color: .gray, size: 12, length: 5)
            btnEye.setImage(UIImage(named: "ic_eye_closed"), for: .normal)
        } else {
            btnEye.setImage(UIImage(named: "ic_eye_flat"), for: .normal)
            lblBalanceValue.text = denomBalance == .fiat ? self.item?.fiat : self.item?.value
            lblBalanceFiat.text = denomBalance == .denom ? self.item?.value : self.item?.fiat
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
