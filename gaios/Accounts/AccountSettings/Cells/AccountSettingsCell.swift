import UIKit
import DGCharts

class AccountSettingsCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblTitle: UILabel!
    var onTap: (() -> Void)?

    class var identifier: String { return String(describing: self) }

    override func prepareForReuse() {}

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        lblTitle.setStyle(.txtBigger)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(model: AccountSettingsCellModel,
                   onTap: (() -> Void)?) {
        self.onTap = onTap
        self.lblTitle.text = model.title
    }

    @IBAction func btnOnTap(_ sender: Any) {
        bg.pressAnimate { [weak self] in
            self?.onTap?()
        }
    }
}
