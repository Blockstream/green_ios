import UIKit

class ChangeAccountCell: UITableViewCell {
    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblAccount: UILabel!
    @IBOutlet weak var lblName: UILabel!
    @IBOutlet weak var iconDisclose: UIImageView!

    class var identifier: String { return String(describing: self) }

    var onTap: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        [lblAccount, lblName].forEach {
            $0.setStyle(.sectionTitle)
        }
    }

    func configure(name: String, type: String, onTap: (() -> Void)?) {
        lblAccount.text = "\("id_account".localized): \(name)"
//        self.lblName.text = name
//        self.onTap = onTap
//        self.iconDisclose.isHidden = onTap == nil
    }
    @IBAction func tap(_ sender: Any) {
//        self.onTap?()
    }
}
