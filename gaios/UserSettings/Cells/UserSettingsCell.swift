import UIKit

class UserSettingsCell: UITableViewCell {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var disclosure: UIImageView!
    @IBOutlet weak var copyImg: UIImageView!
    @IBOutlet weak var switcher: UISwitch!
    
    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        lblTitle.textColor = .white
        lblHint.textColor = .white.withAlphaComponent(0.4)
        bg.layer.cornerRadius = 7.0
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    var viewModel: UserSettingsCellModel? {
        didSet { 
            lblTitle.text = viewModel?.title
            lblHint.text = viewModel?.subtitle
            disclosure.isHidden = !(viewModel?.disclosure ?? false)
            disclosure.image = viewModel?.disclosureImage
            copyImg.isHidden = viewModel?.type != .SupportID
            switcher.isOn = viewModel?.switcher ?? false
            switcher.isHidden = viewModel?.switcher == nil
            switcher.isUserInteractionEnabled = false
            if viewModel?.type == .UnifiedDenominationExchange {
                lblHint.attributedText = viewModel?.attributed ?? NSAttributedString(string: viewModel?.subtitle ?? "")
                lblHint.numberOfLines = 0
            }
        }
    }
}
