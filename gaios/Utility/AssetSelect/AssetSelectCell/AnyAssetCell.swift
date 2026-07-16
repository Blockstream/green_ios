import UIKit

class AnyAssetCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var assetSubview: UIView!
    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var lblAny: UILabel!

    var anyOrAsset: AnyOrAsset?

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        assetSubview.cornerRadius = 5.0
    }

    func configure(_ ref: AnyOrAsset) {
        anyOrAsset = ref

        switch ref {
        case .anyLiquid:
            self.lblAny.text = "Any Liquid Asset".localized
            imgView.image = UIImage(named: "default_asset_liquid_icon")!
        case .anyAmp:
            self.lblAny.text = "Any AMP Asset".localized
            imgView.image = UIImage(named: "default_asset_amp_icon")!
        case .anyAmpLegacy:
            self.lblAny.text = "Any AMP Legacy Asset".localized
            imgView.image = UIImage(named: "default_asset_amp_icon")!
        default:
            break
        }
    }
}
