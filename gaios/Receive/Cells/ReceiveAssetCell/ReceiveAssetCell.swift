import UIKit

class ReceiveAssetCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var lblAsset: UILabel!
    @IBOutlet weak var iconDisclose: UIImageView!
    
    class var identifier: String { return String(describing: self) }

    var onTap: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        lblAsset.setStyle(.titleCard)
    }

    func configure(model: ReceiveAssetCellModel, onTap: (() -> Void)?) {
        self.lblAsset.text = model.title
        self.imgView?.image = model.icon
        self.onTap = onTap
        self.iconDisclose.isHidden = onTap == nil
    }
    @IBAction func tap(_ sender: Any) {
        onTap?()
    }
}
