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
        bg.setStyle(CardStyle.defaultStyle)
        ampSubview.cornerRadius = 5.0
        assetSubview.cornerRadius = 5.0
    }

    func configure(model: AssetSelectCellModel,
                   showEditIcon: Bool) {
        ampSubview.isHidden = true
        assetSubview.borderWidth = 0.0
        iconEdit.isHidden = !showEditIcon

        // Any liquid asset
        if model.anyLiquid {
            self.lblAsset.text = "id_receive_any_liquid_asset".localized
            self.imgView?.image = UIImage(named: "default_asset_liquid_icon")!
            return
        }
        // Any AMP asset
        if model.anyAmp {
            self.lblAsset.text = "Receive any Amp Asset".localized
            self.imgView?.image = UIImage(named: "default_asset_amp_icon")!
            return
        }
        let name = model.asset?.name ?? model.asset?.assetId
        self.lblAsset.text = name
        self.imgView?.image = model.icon

    }
}
