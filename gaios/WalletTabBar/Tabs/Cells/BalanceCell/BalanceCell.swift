import UIKit
import core

enum BalanceDisplayMode {
    case denom
    case fiat

    func next() -> BalanceDisplayMode {
        switch self {
        case .denom:
            return .fiat
        case .fiat:
            return .denom
        }
    }
}

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

    private var balances: [String: Int64]?
    private var currency: String?
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
        lblBalanceTitle.text = "Total Balance".localized
        btnExchange.setImage(UIImage(named: "ic_coins_exchange")?.maskWithColor(color: .white.withAlphaComponent(0.4)), for: .normal)
        lblLoadingAssets.text = "id_loading_assets".localized
        [lblBalanceTitle, lblBalanceFiat].forEach { $0?.setStyle(.txtSectionHeader) }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    // swiftlint:disable:next function_parameter_count
    func configure(balances: [String: Int64]?,
                   currency: String?,
                   item: BalanceItem?,
                   denomBalance: BalanceDisplayMode,
                   hideBalance: Bool,
                   hideBtnExchange: Bool,
                   onHide: ((Bool) -> Void)?,
                   onAssets: (() -> Void)?,
                   onConvert: (() -> Void)?,
                   onExchange: (() -> Void)?) {
        self.balances = balances
        self.currency = currency
        self.item = item
        self.hideBalance = hideBalance
        self.denomBalance = .fiat // force to fiat instead of `denomBalance` as per new spec
        lblBalanceValue.text = ""
        lblBalanceFiat.text = ""
        btnExchange.isHidden = hideBtnExchange
        assetsBox.isHidden = true // assetsCount < 2
        btnAssets.isHidden = true
        iconsView.isHidden = false
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
            lblBalanceValue.text = fiatConvertible()
        }
    }
    func fiatConvertible() -> String {
        var fiatConvertibles: [Decimal] = []
        (balances ?? [:]).forEach {
            if let coinBalance: String =  Balance.fromSatoshi($0.1, assetId: $0.0)?.fiat {
                if let fiatVal = Decimal(string: coinBalance, locale: ConverterManager.enUSLocale) {
                    fiatConvertibles.append(fiatVal)
                }
            }
        }
        var fiatAmount: Decimal?
        if fiatConvertibles.count > 0 {
            fiatAmount = fiatConvertibles.reduce(0, +)
        }
        let converter = WalletManager.current?.converter
        if let fiatAmount, let currency, let result = converter?.formatFiat(value: fiatAmount, currency: currency, withGroupSeparator: true) {
            return result
        } else {
            return "-/- \(converter?.displayFiatCurrency(currency) ?? currency ?? "")"
        }
    }
    @IBAction func onBalanceTap(_ sender: Any) {
        AnalyticsManager.shared.convertBalance(wallet: WalletsStorage.shared.current)
        onConvert?()
    }

    @IBAction func btnEye(_ sender: Any) {
        if !hideBalance { AnalyticsManager.shared.hideAmount(wallet: WalletsStorage.shared.current) }
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
