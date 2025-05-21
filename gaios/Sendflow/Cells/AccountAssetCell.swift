import UIKit
import gdk

class AccountAssetCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!

    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var imgMS: UIImageView!
    @IBOutlet weak var imgSS: UIImageView!
    @IBOutlet weak var imgLigh: UIImageView!
    @IBOutlet weak var lblAsset: UILabel!
    @IBOutlet weak var lblAmount: UILabel!

    @IBOutlet weak var lblAccount: UILabel!
    @IBOutlet weak var lblFiat: UILabel!
    @IBOutlet weak var lblType: UILabel!

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        lblAsset.text = ""
        lblAccount.text = ""
        lblType.text = ""
        imgView.image = UIImage()
        lblAmount.text = ""
        lblFiat.text = ""
    }

    func configure(model: AccountAssetCellModel) {
        self.lblAsset.text = model.asset.name ?? model.asset.assetId
        self.lblAccount.text = model.account.localizedName.uppercased()
        self.lblType.text = model.account.type.shortText.uppercased()

        imgView.image = model.icon
        imgSS.isHidden = !model.account.gdkNetwork.singlesig
        imgMS.isHidden = !model.account.gdkNetwork.multisig
        imgLigh.isHidden = !model.account.gdkNetwork.lightning

        let satoshi = model.balance.first?.value ?? 0
        [lblAmount, lblFiat].forEach { $0.isHidden = true }
        if let balance = Balance.fromSatoshi(satoshi, assetId: model.asset.assetId)?.toValue() {
            lblAmount.text = "\(balance.0) \(balance.1)"
            lblAmount.isHidden = !model.showBalance
        }
        if let balance = Balance.fromSatoshi(satoshi, assetId: model.asset.assetId)?.toFiat() {
            lblFiat.text = "\(balance.0) \(balance.1)"
            lblFiat.isHidden = !model.showBalance
        }
    }
}
