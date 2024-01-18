import UIKit

class AssetSelectCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var assetSubview: UIView!
    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var lblAsset: UILabel!
    @IBOutlet weak var ampSubview: UIView!
    @IBOutlet weak var lblAmp: UILabel!
    @IBOutlet weak var iconEdit: UIImageView!

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.cornerRadius = 5.0
        ampSubview.cornerRadius = 5.0
        assetSubview.cornerRadius = 5.0
    }

    func configure(model: AssetSelectCellModel,
                   showEditIcon: Bool) {
        let name = model.asset?.name ?? model.asset?.assetId
        self.lblAsset.text = name
        self.imgView?.image = model.icon

        ampSubview.isHidden = true
        assetSubview.borderWidth = 0.0
        iconEdit.isHidden = !showEditIcon
    }
}
