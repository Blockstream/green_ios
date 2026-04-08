import UIKit

class LTRecoverFundsSummaryCell: UITableViewCell {

    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var FiatTextLabel: UILabel!

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(amount: String, fiat: String) {
        amountTextField.text = "\(amount)"
        FiatTextLabel.text = "\(fiat)"
    }
}
