import UIKit

class ShowMnemonicFooterView: UIView {
    @IBOutlet weak var safeEnvironmentIcon: UIImageView!
    @IBOutlet weak var safeEnvironmentTitle: UILabel!
    @IBOutlet weak var safeEnvironmentDescription: UILabel!

    @IBOutlet weak var sensitiveInfoIcon: UIImageView!
    @IBOutlet weak var sensitiveInfoTitle: UILabel!
    @IBOutlet weak var sensitiveInfoDescription: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        setContent()
        setStyle()
    }

    func setContent() {
        safeEnvironmentIcon.image = UIImage(named: "ic_info_home")!.withTintColor(UIColor.gAccent())
        safeEnvironmentTitle.text = "id_safe_environment".localized
        safeEnvironmentDescription.text = "id_make_sure_you_are_alone_and_no".localized

        sensitiveInfoIcon.image = UIImage(named: "ic_info_warn")!.withTintColor(UIColor.gAccent())
        sensitiveInfoTitle.text = "id_sensitive_information".localized
        sensitiveInfoDescription.text = "id_whomever_can_access_your".localized
    }

    func setStyle() {
        [safeEnvironmentTitle, sensitiveInfoTitle].forEach {
            $0?.font = UIFont.systemFont(ofSize: 14.0, weight: .medium)
            $0?.textColor = .black
        }
        [safeEnvironmentDescription, sensitiveInfoDescription].forEach {
            $0?.font = UIFont.systemFont(ofSize: 12.0, weight: .regular)
            $0?.textColor = .gGrayTxt()
        }
    }
}
