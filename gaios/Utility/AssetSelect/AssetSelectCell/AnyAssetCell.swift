import UIKit

enum AnyAssetType {
    case liquid
    case amp
}

class AnyAssetCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var assetSubview: UIView!
    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var lblAny: UILabel!

    var anyAssetType: AnyAssetType?

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        assetSubview.cornerRadius = 5.0
    }

    func configure(_ type: AnyAssetType) {
        anyAssetType = type

        switch type {
        case .liquid:
            self.lblAny.text = "id_receive_any_liquid_asset".localized
            imgView.image = UIImage(named: "default_asset_liquid_icon")!
        case .amp:
            self.lblAny.text = "id_receive_any_amp_asset".localized
            imgView.image = UIImage(named: "default_asset_amp_icon")!
        }
    }
}
