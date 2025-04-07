import UIKit
import DGCharts

class PreferenceCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var lblState: UILabel!
    var onTap: (() -> Void)?

    class var identifier: String { return String(describing: self) }

    override func prepareForReuse() {}

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        lblTitle.setStyle(.txtBigger)
        lblHint.setStyle(.txtCard)
        lblState.setStyle(.txtBigger)
        lblState.textColor = UIColor.gGrayTxt()
        lblState.text = ""
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(model: PreferenceCellModel,
                   onTap: (() -> Void)?) {
        self.onTap = onTap
        self.icon.image = model.icImg
        self.lblTitle.text = model.title
        self.lblHint.text = model.hint
        self.lblState.text = model.state.rawValue
    }

    @IBAction func btnOnTap(_ sender: Any) {
        bg.pressAnimate { [weak self] in
            self?.onTap?()
        }
    }
}
