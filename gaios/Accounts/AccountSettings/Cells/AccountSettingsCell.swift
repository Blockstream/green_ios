import UIKit
import DGCharts

class AccountSettingsCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblTitle: UILabel!
    var model: AccountSettingsCellModel?
    var onTap: (() -> Void)?

    class var identifier: String { return String(describing: self) }

    override func prepareForReuse() {}

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        lblTitle.setStyle(.txtBigger)
        self.bg.alpha = 1.0
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(model: AccountSettingsCellModel,
                   onTap: (() -> Void)?) {
        self.model = model
        self.onTap = onTap
        self.lblTitle.text = model.title
        switch model.type {
        case .archive:
            if model.isFunded == true {
                self.onTap = nil
                self.bg.alpha = 0.4
            }
        default:
            break
        }
    }

    @IBAction func btnOnTap(_ sender: Any) {
        if onTap == nil { return }
        bg.pressAnimate { [weak self] in
            self?.onTap?()
        }
    }
}
