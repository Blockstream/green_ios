import UIKit

class DialogDetailCell: UITableViewCell {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        lblTitle.font = UIFont.systemFont(ofSize: 14.0, weight: .regular)
        lblTitle.textColor = .white
        lblHint.font = UIFont.systemFont(ofSize: 14.0, weight: .regular)
        lblHint.textColor = .white.withAlphaComponent(0.4)
    }

    override func prepareForReuse() {
        lblTitle.text = ""
        lblHint.text = ""
    }

    func configure(_ title: String, _ hint: String, _ truncate: Bool = false) {
        self.lblTitle.text = title
        self.lblHint.text = hint
        if truncate {
            lblHint.numberOfLines = 1
            lblHint.lineBreakMode = .byTruncatingMiddle
        }
    }

    func configureAmount(_ title: String, _ hint: String, _ hideBalance: Bool = false) {
        self.lblTitle.text = title
        self.lblHint.text = hint
        if hideBalance {
            self.lblHint.attributedText = Common.obfuscate(color: .white, size: 14, length: 5)
        }
    }
}
