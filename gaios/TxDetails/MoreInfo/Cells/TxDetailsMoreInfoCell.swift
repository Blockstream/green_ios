import UIKit

class TxDetailsMoreInfoCell: UITableViewCell {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        lblTitle.setStyle(.txtCard)
        lblHint.setStyle(.txt)
    }

    func configure(model: TxDetailsMoreInfoCellModel) {
        self.lblTitle.text = model.title
        self.lblHint.text = model.hint
    }
}
