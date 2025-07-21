import UIKit
import gdk
import core

class DialogAccountCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblName: UILabel!
    @IBOutlet weak var lblType: UILabel!
    @IBOutlet weak var lblAmount: UILabel!
    @IBOutlet weak var lblFiat: UILabel!

    private var hideBalance: Bool = false
    private var isLast: Bool = false
    var isSelectable: Bool = false
    private var onTap: (() -> Void)?

    static var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        bg.borderColor = .white.withAlphaComponent(0.1)
        [lblName, lblAmount].forEach {
            $0?.setStyle(.txtBigger)
        }
        [lblType, lblFiat].forEach {
            $0?.setStyle(.txtCard)
        }
    }

    func stringForAttachment() -> NSAttributedString {
        if #available(iOS 13.0, *) {
            let attachment = NSTextAttachment()
            let image = UIImage(systemName: "asterisk")?.withTintColor(.white)
            attachment.image = image
            let fullString = NSMutableAttributedString(string: "")
            fullString.append(NSAttributedString(attachment: attachment))
            return fullString
        } else {
            return NSAttributedString()
        }
    }

    func configure(model: AccountCellModel,
                   isSelectable: Bool,
                   hideBalance: Bool,
                   onTap: (() -> Void)?
    ) {
        self.hideBalance = hideBalance
        self.isSelectable = isSelectable
        self.onTap = onTap

        lblType.text = model.lblType
        lblName.text = model.name.localized

        if hideBalance {
            lblFiat.attributedText = Common.obfuscate(color: UIColor.gGrayTxt(), size: 12, length: 5)
            lblAmount.attributedText = Common.obfuscate(color: .white, size: 16, length: 5)
        } else {
            lblFiat.text = model.fiatStr ?? ""
            lblAmount.text = model.balanceStr ?? ""
        }
        reloadAmounts(model)
    }

    func reloadAmounts(_ model: AccountCellModel) {
        let list = model.hasTxs ? model.account.satoshi ?? [:] : [:]
        let assets = AssetAmountList(list)
        let registry = WalletManager.current
        var icons = [UIImage]()
        assets.amounts.compactMap {
            if model.networkType.lightning && $0.0 == "btc" {
                return UIImage(named: "ic_lightning_btc")
            }
            return registry?.image(for: $0.0)
        }
        .forEach { if !icons.contains($0) { icons += [$0] } }
    }

    @IBAction func btnTap(_ sender: Any) {
        if isSelectable {
            isSelectable = false
            bg.pressAnimate {
                self.onTap?()
            }
        }
    }
}
