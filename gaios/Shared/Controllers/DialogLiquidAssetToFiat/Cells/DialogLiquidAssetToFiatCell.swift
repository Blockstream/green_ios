import UIKit


class DialogLiquidAssetToFiatCell: UITableViewCell {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var icon: UIImageView!

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        lblTitle.setStyle(.titleCard)
        lblHint.setStyle(.txtCard)
        icon.image = UIImage(named: "ic_check_circle")?.maskWithColor(color: UIColor.gAccent())
    }

    override func prepareForReuse() {
        lblTitle.text = ""
        lblHint.text = ""
        icon.isHidden = true
    }

    func configure(assetName: String,
                   assetAmountTxt: String,
                   isSelected: Bool) {
        lblTitle.text = assetName
        icon.isHidden = isSelected == false
        lblTitle.textColor = isSelected ? UIColor.gAccent() : .white
        lblHint.text = assetAmountTxt
    }
}
