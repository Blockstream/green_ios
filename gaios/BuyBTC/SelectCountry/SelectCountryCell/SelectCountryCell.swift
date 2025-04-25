import UIKit

class SelectCountryCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    var onTap: (() -> Void)?
    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        lblTitle.setStyle(.txtBold)
        lblHint.setStyle(.txtCard)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(model: SelectCountryCellModel,
                   onTap: (() -> Void)?) {
        icon.image = model.icon
        lblTitle.text = model.title
        lblHint.text = model.hint
        self.onTap = onTap
    }
    @IBAction func btnTap(_ sender: Any) {
        bg.pressAnimate {
            self.onTap?()
        }
    }
}
