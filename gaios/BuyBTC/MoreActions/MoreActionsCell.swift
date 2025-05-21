import UIKit

class MoreActionsCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblTitle: UILabel!
    var onTap: (() -> Void)?
    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        lblTitle.setStyle(.txtBold)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(model: BuyMoreActions,
                   onTap: (() -> Void)?) {
        lblTitle.text = model.title
        self.onTap = onTap
    }
    
    func configure(model: SetupNewMoreActions,
                   onTap: (() -> Void)?) {
        lblTitle.text = model.title
        self.onTap = onTap
    }
    @IBAction func btnTap(_ sender: Any) {
        bg.pressAnimate {
            self.onTap?()
        }
    }
}
