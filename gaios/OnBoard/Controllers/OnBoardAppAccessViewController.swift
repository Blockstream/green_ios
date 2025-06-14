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
        lblHead.text = "APP ACCESS".localized
        lblTitle.text = "Select your unlock method".localized
        lblHint.text = "You need an unlock method to access your wallet and funds. ".localized
        lblTitleBio.text = hasTouchID ? "TouchID".localized : "FaceID".localized
        lblHintBio.text =  hasTouchID ? "Device access using TouchID.".localized : "Device access using FaceID.".localized
        lblTitlePin.text = "PIN".localized
        lblHintPin.text = "Unlock your wallet using PIN.".localized
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
