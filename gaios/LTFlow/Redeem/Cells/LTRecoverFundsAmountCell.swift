import UIKit

class LTRecoverFundsAmountCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var amountTextField: DecimalTextField!
    @IBOutlet weak var denominationLabel: UILabel!

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        amountTextField.maxDecimalsProvider = { 8 }
    }

    func configure(amount: String, isEditing: Bool) {
        amountTextField.text = "\(amount)"
        amountTextField.isUserInteractionEnabled = isEditing
        amountTextField.isEnabled = isEditing
        denominationLabel.text = ""
    }
}
