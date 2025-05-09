import UIKit

class WalletAssetCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var lblAsset: UILabel!
    @IBOutlet weak var lblBalance1: UILabel!
    @IBOutlet weak var lblBalance2: UILabel!

    class var identifier: String { return String(describing: self) }

    var onTap: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        lblAsset.setStyle(.titleCard)
        lblBalance1.setStyle(.txt)
        lblBalance1.setStyle(.txtBold)
        lblBalance1.textColor = UIColor.gAccent()
        lblBalance2.setStyle(.txtCard)
    }

    func configure(model: WalletAssetCellModel, onTap: (() -> Void)?) {
        self.lblAsset.text = model.asset?.name ?? model.asset?.assetId
        self.lblBalance1.text = model.hidden ? "" : (model.value ?? "")
        self.lblBalance2.text = model.hidden ? "" : (model.fiat ?? " - ")
        if model.masked {
            self.lblBalance1.attributedText = Common.obfuscate(color: UIColor.gAccent(), size: 14, length: 5)
            self.lblBalance2.attributedText = Common.obfuscate(color: .lightGray, size: 12, length: 5)
        }
        self.imgView?.image = model.icon
        self.onTap = onTap
    }
    @IBAction func tap(_ sender: Any) {
        onTap?()
    }
}
