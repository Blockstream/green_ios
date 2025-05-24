import UIKit
import gdk
import core

class TxDetailsMultiAmountCell: UITableViewCell {

    class var identifier: String { return String(describing: self) }

    var model: TxDetailsAmountCellModel?
    var copyAmount: ((String) -> Void)?

    @IBOutlet weak var lblAmount: UILabel!
    @IBOutlet weak var lblAsset: UILabel!
    @IBOutlet weak var lblFiat: UILabel!
    @IBOutlet weak var iconAsset: UIImageView!
    @IBOutlet weak var iconSide: UIImageView!

    private var btc: String {
        return WalletManager.current?.account.gdkNetwork.getFeeAsset() ?? ""
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        lblAmount.setStyle(.subTitle)
        lblFiat.setStyle(.txtCard)
        lblAsset.setStyle(.txt)
        lblAsset.textColor = UIColor.gAccent()
    }

    func configure(model: TxDetailsAmountCellModel,
                   copyAmount: ((String) -> Void)?) {
        self.model = model
        self.copyAmount = copyAmount

        iconSide.image = model.iconSide
        loadIcon()

        if let balance = Balance.fromSatoshi(model.value, assetId: model.id) {
            let (amount, denom) = balance.toValue()
            lblAmount.attributedText = formatAmount(amount)
            lblAsset.text = denom
            let (fiat, curr) = balance.toFiat()
            lblFiat.text = "≈ \(fiat) \(curr)"
            lblFiat.isHidden = model.id != model.tx.feeAsset
            if model.hideBalance {
                lblAmount.attributedText = Common.obfuscate(color: .white, size: 14, length: 5)
                lblAsset.attributedText = Common.obfuscate(color: UIColor.gAccent(), size: 10, length: 3)
                lblFiat.attributedText =  Common.obfuscate(color: .white, size: 10, length: 5)
            }
        }
    }

    func loadIcon() {
        if model?.tx.subaccount?.gdkNetwork.lightning ?? false {
            iconAsset.image = UIImage(named: "ic_lightning_btc")
        } else {
            iconAsset.image = WalletManager.current?.image(for: model!.id)
        }
    }

    func formatAmount(_ amount: String) -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: 20.0, weight: .regular)

        let decimalSeparator = Locale.current.decimalSeparator
        if let decimalSeparator = decimalSeparator {
            let components: [String] = amount.components(separatedBy: decimalSeparator)
            if components.count == 2 {
                let intPart = components[0]
                var decPart = components[1]
                if decPart.count == 8 {
                    decPart = "\(decPart[0..<3]) \(decPart[3..<6]) \(decPart[6..<8])"
                }
                let attributedLeftPart = NSMutableAttributedString(string: intPart + decimalSeparator)
                let attributedRightPart = NSMutableAttributedString(string: decPart)
                attributedLeftPart.addAttribute(.font, value: font, range: NSRange(location: 0, length: attributedLeftPart.length))
                attributedRightPart.addAttribute(.font, value: font, range: NSRange(location: 0, length: attributedRightPart.length))
                let final = NSMutableAttributedString()
                final.append(attributedLeftPart)
                final.append(attributedRightPart)
                return final
            }
        }
        let final = NSMutableAttributedString(string: amount)
        final.addAttribute(.font, value: font, range: NSRange(location: 0, length: final.length))
        return final
    }
}
