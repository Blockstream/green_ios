import UIKit

class LTRecoverFundsErrorCell: UITableViewCell {
    @IBOutlet weak var errorLabel: UILabel!

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(text: String) {
        errorLabel.text = "\(text)"
    }
}
