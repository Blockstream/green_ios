import UIKit
import DGCharts

class LTSettingCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var lblState: UILabel!

    class var identifier: String { return String(describing: self) }

    override func prepareForReuse() {}

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        lblTitle.setStyle(.txt)
        lblHint.setStyle(.txtCard)
        lblState.setStyle(.txtCard)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(model: LTSettingCellModel) {
        self.icon.isHidden = model.hiddenIcon
        self.lblTitle.text = model.title
        self.lblHint.text = model.subtitle
        self.lblState.text = model.value
        self.lblState.textColor = UIColor.gGrayTxt()
    }
}
