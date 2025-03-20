import UIKit

class OnBoardAppAccessViewController: UIViewController {

    @IBOutlet weak var lblHead: UILabel!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var viewFace: UIView!
    @IBOutlet weak var viewPin: UIView!
    @IBOutlet weak var lblTitleFace: UILabel!
    @IBOutlet weak var lblHintFace: UILabel!
    @IBOutlet weak var lblTitlePin: UILabel!
    @IBOutlet weak var lblHintPin: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
    }

    func setContent() {
        lblHead.text = "APP ACCESS".localized
        lblTitle.text = "Select your unlock method".localized
        lblHint.text = "You need an unlock method to access your wallet and funds. ".localized
        lblTitleFace.text = "FaceID".localized
        lblHintFace.text = "Device access using FaceID.".localized
        lblTitlePin.text = "PIN".localized
        lblHintPin.text = "Unlock your wallet using PIN.".localized
    }

    func setStyle() {
        [viewFace, viewPin].forEach {
            $0?.setStyle(CardStyle.defaultStyle)
        }
        lblHead.setStyle(.txtCard)
        lblTitle.setStyle(.subTitle)
        lblHint.setStyle(.txtCard)
        [lblTitleFace, lblTitlePin].forEach {
            $0?.setStyle(.txtBold)
        }
        [lblHintFace, lblHintPin].forEach {
            $0?.setStyle(.txtCard)
        }
    }

    @IBAction func btnFace(_ sender: Any) {
        viewFace.pressAnimate {
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
