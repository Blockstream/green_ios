import UIKit

class ReceiveAssetCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var lblAsset: UILabel!
    @IBOutlet weak var iconDisclose: UIImageView!
    @IBOutlet weak var viewLightReady: UIView!
    @IBOutlet weak var iconLightReady: UIImageView!
    @IBOutlet weak var lblLightReady: UILabel!

    class var identifier: String { return String(describing: self) }

    var onTap: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        lblAsset.setStyle(.titleCard)
    }

    func configure(model: ReceiveAssetCellModel,
                   hasLwkSession: Bool = false,
                   onTap: (() -> Void)?) {
        self.lblAsset.text = model.title
        self.imgView?.image = model.icon
        self.onTap = onTap
        self.iconDisclose.isHidden = onTap == nil
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
    @IBAction func tap(_ sender: Any) {
        onTap?()
    }
}
