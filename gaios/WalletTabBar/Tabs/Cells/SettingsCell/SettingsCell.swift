import UIKit

class SettingsCell: UITableViewCell {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var lblTag: UILabel!

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        lblTitle.setStyle(.txtBigger)
        lblHint.setStyle(.txtCard)
        lblTag.setStyle(.txtCard)
        lblTag.text = ""
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    var viewModel: TabSettingsCellModel? {
        didSet {
            lblTitle.text = viewModel?.title
            lblHint.text = viewModel?.subtitle
            icon.image = viewModel?.icon

            if viewModel?.type == .unifiedDenominationExchange {
                lblHint.attributedText = viewModel?.attributed ?? NSAttributedString(string: viewModel?.subtitle ?? "")
                lblHint.numberOfLines = 0
            }
            lblTag.text = viewModel?.type == .lightning ? "Beta" : ""
        }
    }
}
