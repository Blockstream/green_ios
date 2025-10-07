import UIKit

class AssetSelectCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var assetSubview: UIView!
    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var lblAsset: UILabel!
    @IBOutlet weak var ampSubview: UIView!
    @IBOutlet weak var lblAmp: UILabel!
    @IBOutlet weak var iconEdit: UIImageView!
    @IBOutlet weak var viewLightReady: UIView!
    @IBOutlet weak var iconLightReady: UIImageView!
    @IBOutlet weak var lblLightReady: UILabel!

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        ampSubview.cornerRadius = 5.0
        assetSubview.cornerRadius = 5.0
        viewLightReady.isHidden = true
    }

    func configure(model: AssetSelectCellModel,
                   showEditIcon: Bool,
                   hasLwkSession: Bool = false) {
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
            self.lblAsset.text = "id_receive_any_amp_asset".localized
            self.imgView?.image = UIImage(named: "default_asset_amp_icon")!
            return
        }
        let name = model.asset?.name ?? model.asset?.assetId
        self.lblAsset.text = name
        self.imgView?.image = model.icon

        if model.isLBTC() && hasLwkSession {
            configureLightningReady()
        } else {
            viewLightReady.isHidden = true
        }
    }
    func configureLightningReady() {
        viewLightReady.isHidden = false
        iconLightReady.image = UIImage(named: "ic_shortcut_light")!.maskWithColor(color: .gLightning())
        lblLightReady.text = "Lightning Ready".localized
        viewLightReady.borderWidth = 1.0
        viewLightReady.borderColor = .gLightning()
        viewLightReady.cornerRadius = 5.0
        lblLightReady.setStyle(.txtSmaller)
        lblLightReady.textColor = .gLightning()
    }
}
