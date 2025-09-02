//

import UIKit

class LangCell: UITableViewCell {
    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var iconCurrent: UIImageView!

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        lblTitle.setStyle(.txtBigger)
        lblHint.setStyle(.txtCard)
        iconCurrent.isHidden = true
    }
    override func prepareForReuse() {
        iconCurrent.isHidden = true
    }

    func configure(_ model: LangCellModel) {
        lblTitle.text = model.title
        lblHint.text = model.hint
        iconCurrent.isHidden = !model.isCurrent
        iconCurrent.image = UIImage(named: "ic_check_circle")?.maskWithColor(color: UIColor.gAccent())
    }
}
