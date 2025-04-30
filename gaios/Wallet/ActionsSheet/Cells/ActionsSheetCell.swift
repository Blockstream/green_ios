import UIKit

class ActionsSheetCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var btnDisclose: UIButton!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var icon: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.cornerRadius = 5.0
        bg.backgroundColor = UIColor.gGrayElement()
        btnDisclose.isUserInteractionEnabled = false
        btnDisclose.backgroundColor = UIColor.gAccent()
        btnDisclose.cornerRadius = 4.0
        lblTitle.setStyle(.txtBigger)
        lblHint.setStyle(.txtCard)
    }

    class var identifier: String { return String(describing: self) }

    override func prepareForReuse() {
        super.prepareForReuse()
    }

    func configure(model: ActionsSheetCellModel) {
        lblTitle.text = model.title
        lblHint.text = model.hint
        icon.image = model.icon
    }
}
