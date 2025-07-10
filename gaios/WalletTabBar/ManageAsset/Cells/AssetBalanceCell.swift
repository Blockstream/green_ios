import UIKit
import core
import gdk

class AssetBalanceCell: UITableViewCell {

    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var lblBalanceValue: UILabel!
    @IBOutlet weak var lblBalanceFiat: UILabel!

    private var hideBalance = false

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        lblBalanceValue.setStyle(.subTitle24)
        lblBalanceFiat.setStyle(.txtCard)
        lblBalanceValue.text = ""
        lblBalanceFiat.text = ""
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(assetId: String,
                   satoshi: Int64,
                   hideBalance: Bool) {
        self.hideBalance = hideBalance
        let img = WalletManager.current?.image(for: assetId)
        icon.image = img
        if let balance = Balance.fromSatoshi(satoshi, assetId: assetId)?.toValue() {
            lblBalanceValue.text = "\(balance.0) \(balance.1)"
        }
        if let balance = Balance.fromSatoshi(satoshi, assetId: assetId)?.toFiat() {
            lblBalanceFiat.text = "\(balance.0) \(balance.1)"
        }
        if hideBalance {
            self.lblBalanceValue.attributedText = Common.obfuscate(color: UIColor.white, size: 24, length: 5)
            self.lblBalanceFiat.attributedText = Common.obfuscate(color: UIColor.gGrayTxt(), size: 14, length: 5)
        }
    }
}
