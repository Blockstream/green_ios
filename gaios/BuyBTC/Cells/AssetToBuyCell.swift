import UIKit

class AssetToBuyCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var lblAsset: UILabel!
    @IBOutlet weak var lblBalance1: UILabel!
    @IBOutlet weak var lblBalance2: UILabel!

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.cornerRadius = 5.0
    }

    func configure(model: AssetToBuyCellModel) {
        self.lblAsset.text = model.asset?.name ?? model.asset?.assetId
        self.imgView?.image = model.icon
    }
}
