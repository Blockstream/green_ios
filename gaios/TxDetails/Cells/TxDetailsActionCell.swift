import UIKit

class TxDetailsActionCell: UITableViewCell {

    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var hintView: UIView!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var divider: UIView!
    
    class var identifier: String { return String(describing: self) }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        lblTitle.setStyle(.txtSmallerBold)
        lblTitle.textColor = UIColor.gGreenMatrix()
        hintView.backgroundColor = UIColor.gGreenMatrix()
        hintView.layer.cornerRadius = hintView.frame.size.height / 2.0
        lblHint.setStyle(.txtSmallerBold)
    }

    func configure(model: TxDetailsActionCellModel, isLast: Bool) {
        self.icon.image = model.icon
        self.lblTitle.text = model.title
        hintView.isHidden = model.action != .speedUp
        lblHint.text = "id_increase_fee".localized
        divider.isHidden = isLast
    }
}
