//

import UIKit

class TitleCell: UITableViewCell {

    @IBOutlet weak var lblTitle: UILabel!
    class var identifier: String { return String(describing: self) }
    override func awakeFromNib() {
        super.awakeFromNib()
        lblTitle.setStyle(.txtBigger)
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    func configure(_ title: String) {
        self.lblTitle.text = title
    }
}
