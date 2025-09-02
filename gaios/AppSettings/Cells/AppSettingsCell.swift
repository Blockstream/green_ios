import UIKit
import gdk

class AppSettingsCell: UITableViewCell {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var actionSwitch: UISwitch!
    var type: AppSettingsCellType?
    @IBOutlet weak var btnHelp: UIButton!
    @IBOutlet weak var btnTap: UIButton!
    @IBOutlet weak var rightArrow: UIImageView!
    var onActionSwitch: (() -> Void)?
    var onTap: (() -> Void)?
    var onHelp: (() -> Void)?

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        lblTitle.setStyle(.txtBigger)
        lblHint.setStyle(.txtCard)
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    func configure(type: AppSettingsCellType,
                   switchState: Bool?,
                   onActionSwitch: (() -> Void)? = nil,
                   onHelp: (() -> Void)? = nil,
                   onTap: (() -> Void)? = nil) {
        self.type = type
        self.onTap = onTap
        self.onActionSwitch = onActionSwitch
        self.onHelp = onHelp
        rightArrow.isHidden = switchState != nil
        actionSwitch.isHidden = switchState == nil
        actionSwitch.isOn = switchState == true
        btnTap.isHidden = onTap == nil
        btnHelp.isHidden = onHelp == nil
        btnHelp.setStyle(.inline)
        switch type {
        case .tor:
            lblTitle.text = "id_connect_with_tor".localized
            lblHint.text = "id_private_but_less_stable".localized
        case .proxy:
            lblTitle.text = "id_connect_through_a_proxy".localized
            lblHint.text = ""
        case .hw:
            lblTitle.text = "id_remember_hardware_devices".localized
            lblHint.text = ""
        case .testnet:
            lblTitle.text = "id_enable_testnet".localized
            lblHint.text = ""
        case .help:
            lblTitle.text = "id_help_us_improve".localized
            lblHint.text = "id_enable_limited_usage_data".localized
            btnHelp.setTitle("id_more_info".localized, for: .normal)
        case .experimental:
            lblTitle.text = "id_enable_experimental_features".localized
            lblHint.text = "id_experimental_features_might".localized
        case .language:
            lblTitle.text = "id_language".localized
            lblHint.text = ""
        case .meld:
            lblTitle.text = "Meld".localized
            lblHint.text = "Enable Meld sendbox".localized
        case .electrum:
            lblTitle.text = "id_personal_electrum_server".localized
            lblHint.text = ""
        default:
            break
        }
    }
    @IBAction func onHelp(_ sender: Any) {
        onHelp?()
    }
    @IBAction func actionSwitchChanged(_ sender: Any) {
        onActionSwitch?()
    }
    @IBAction func onTap(_ sender: Any) {
        pressAnimate {
            self.onTap?()
        }
    }
}
