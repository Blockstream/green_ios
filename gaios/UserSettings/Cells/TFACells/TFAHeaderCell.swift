import UIKit

class TFAHeaderCell: UITableViewCell {

    @IBOutlet weak var lblTitle: UILabel!

    class var identifier: String { return String(describing: self) }

    override func prepareForReuse() {}

    override func awakeFromNib() {
        super.awakeFromNib()
        lblTitle.setStyle(.txtBigger)
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    func configure() {
        lblTitle.text = "Enable Two-Factor Authentication to add additional protection to your wallet".localized
    }
}
