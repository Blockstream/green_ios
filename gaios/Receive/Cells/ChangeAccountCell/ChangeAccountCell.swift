import UIKit

class ChangeAccountCell: UITableViewCell {
    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblAccount: UILabel!
    @IBOutlet weak var lblName: UILabel!

    class var identifier: String { return String(describing: self) }

    var onTap: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        [lblAccount, lblName].forEach {
            $0.setStyle(.sectionTitle)
        }
    }

    func configure(name: String, onTap: (() -> Void)?) {
        lblAccount.text = "id_account".localized
        self.lblName.text = name
        self.onTap = onTap
    }
    @IBAction func tap(_ sender: Any) {
        self.onTap?()
    }
}
