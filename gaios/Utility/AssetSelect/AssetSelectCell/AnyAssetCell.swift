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
            self.lblAny.text = "id_receive_any_liquid_asset".localized
            imgView.image = UIImage(named: "default_asset_liquid_icon")!
        case .anyAmp:
            self.lblAny.text = "id_receive_any_amp_asset".localized
            imgView.image = UIImage(named: "default_asset_amp_icon")!
        default:
            break
        }
    }
}
