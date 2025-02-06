//

import UIKit

class LangCell: UITableViewCell {
    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblLangTtitle: UILabel!
    @IBOutlet weak var lblLangHint: UILabel!
    @IBOutlet weak var iconCurrent: UIImageView!

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.cornerRadius = 5.0
        iconCurrent.isHidden = true
    }
    override func prepareForReuse() {
        iconCurrent.isHidden = true
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(_ model: LangCellModel) {
        lblLangTtitle.text = model.title
        lblLangHint.text = model.hint
        iconCurrent.isHidden = !model.isCurrent
    }
}
