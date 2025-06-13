import UIKit
import core
class OnBoardAppAccessViewController: UIViewController {

    @IBOutlet weak var lblHead: UILabel!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var viewBio: UIView!
    @IBOutlet weak var viewPin: UIView!
    @IBOutlet weak var lblTitleBio: UILabel!
    @IBOutlet weak var lblHintBio: UILabel!
    @IBOutlet weak var lblTitlePin: UILabel!
    @IBOutlet weak var lblHintPin: UILabel!
    @IBOutlet weak var iconBio: UIImageView!

    var hasTouchID: Bool {
        return AuthenticationTypeHandler.biometryType == .touchID
    }
    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
    }

    func setContent() {
        lblHead.text = "id_app_access".localized
        lblTitle.text = "id_select_your_unlock_method".localized
        lblHint.text = "id_you_need_an_unlock_method_to".localized
        lblTitleBio.text = hasTouchID ? "id_touchid".localized : "id_faceid".localized
        lblHintBio.text =  hasTouchID ? "id_device_access_using_touchid".localized : "id_device_access_using_faceid".localized
        lblTitlePin.text = "id_pin".localized
        lblHintPin.text = "id_unlock_your_wallet_using_pin".localized
        let icName = hasTouchID ? "touchid" : "faceid"
        iconBio.image = UIImage(systemName: icName)?.maskWithColor(color: UIColor.gGrayTxt())
    }

    func setStyle() {
        [viewBio, viewPin].forEach {
            $0?.setStyle(CardStyle.defaultStyle)
        }
        lblHead.setStyle(.txtCard)
        lblTitle.setStyle(.subTitle)
        lblHint.setStyle(.txtCard)
        [lblTitleBio, lblTitlePin].forEach {
            $0?.setStyle(.txtBold)
        }
        [lblHintBio, lblHintPin].forEach {
            $0?.setStyle(.txtCard)
        }
    }

    @IBAction func btnFace(_ sender: Any) {
        viewBio.pressAnimate {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }

    @IBAction func btnPin(_ sender: Any) {
        viewPin.pressAnimate {
            let flow = UIStoryboard(name: "OnBoard", bundle: nil)
            if let vc = flow.instantiateViewController(withIdentifier: "OnBoardAppPinViewController") as? OnBoardAppPinViewController {
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
}
