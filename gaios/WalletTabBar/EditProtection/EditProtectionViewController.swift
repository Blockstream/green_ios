import UIKit

enum EditProtectionType {
    case pin
    case faceID
    case touchID
}
enum EditProtectionAction {
    case enable
    case disable
    case change
}
class EditProtectionViewController: UIViewController {

    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnNext: UIButton!

    var protectionType: EditProtectionType?
    var protectionAction: EditProtectionAction?

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
    }

    func setContent() {
        guard let protectionType = protectionType, let protectionAction = protectionAction else {
            navigationController?.popViewController(animated: true)
            return
        }
        switch protectionType {
        case .pin:
            icon.image = UIImage(named: "ic_edit_protection_pin")
            lblTitle.text = "PIN".localized
            lblHint.text = "Warning: If you forget your PIN and have not enabled biometrics or a recovery method, you will lose access to funds.".localized
            lblHint.isHidden = false
            switch protectionAction {
            case .enable:
                btnNext.setTitle("Enable".localized, for: .normal)
            case .disable:
                break
            case .change:
                btnNext.setTitle("Change PIN".localized, for: .normal)
            }
        case .faceID:
            icon.image = UIImage(named: "ic_edit_protection_face")
            lblTitle.text = "FaceID".localized
            lblHint.isHidden = true
            switch protectionAction {
            case .enable:
                btnNext.setTitle("Enable".localized, for: .normal)
            case .disable:
                btnNext.setTitle("Disable".localized, for: .normal)
            case .change:
                break
            }
        case .touchID:
            icon.image = UIImage(named: "ic_edit_protection_touch")
            lblTitle.text = "Touch ID".localized
            lblHint.isHidden = true
            switch protectionAction {
            case .enable:
                btnNext.setTitle("Enable".localized, for: .normal)
            case .disable:
                btnNext.setTitle("Disable".localized, for: .normal)
            case .change:
                break
            }
        }
    }

    func setStyle() {
        lblTitle.setStyle(.txtBigger)
        lblHint.setStyle(.txt)
        btnNext.setStyle(.primary)
    }

    @IBAction func btnNext(_ sender: Any) {

    }
}
