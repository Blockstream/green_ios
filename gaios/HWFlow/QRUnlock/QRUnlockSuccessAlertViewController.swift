import Foundation
import UIKit

protocol QRUnlockSuccessAlertViewControllerDelegate: AnyObject {
    func onTap(_ action: QRUnlockSuccessAlertAction)
}

enum QRUnlockSuccessAlertAction {
    case learnMore
    case faceID
    case later
}

class QRUnlockSuccessAlertViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!

    @IBOutlet weak var lblLearnMore: UILabel!
    @IBOutlet weak var btnLearnMore: UIButton!
    @IBOutlet weak var btnFaceID: UIButton!
    @IBOutlet weak var btnLater: UIButton!
    @IBOutlet weak var lblInfoCredentials: UILabel!

    weak var delegate: QRUnlockSuccessAlertViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        setStyle()
        setContent()
        view.alpha = 0.0

        if AuthenticationTypeHandler.biometryType == .faceID {
            imgBio.image = UIImage(named: "ic_airgap_faceid")!
            btnBio.setTitle("id_enable_face_id".localized, for: .normal)
            lblTitle.text = String(format: "id_use_s_for_quick_access".localized, "Face ID")
        } else if AuthenticationTypeHandler.biometryType == .touchID {
            imgBio.image = UIImage(named: "ic_airgap_biometrics")!
            btnBio.setTitle("id_enable_touch_id".localized, for: .normal)
            lblTitle.text = String(format: "id_use_s_for_quick_access".localized, "Touch ID")
        } else {
            imgBio.image = UIImage(named: "ic_airgap_biometrics")!
            btnBio.setTitle("id_touchface_id_not_available", for: .normal)
            lblTitle.text = "id_success".localized
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
    }

    func setContent() {
        lblHint.text = "Access your wallet to check your wallet balance and transactions.\n\nSign transactions offline using your Jade.".localized
    }

    func setStyle() {
        cardView.layer.cornerRadius = 10
        cardView.borderWidth = 1.0
        cardView.borderColor = .white.withAlphaComponent(0.05)
        lblTitle.setStyle(.titleCard)
        lblHint.setStyle(.txtCard)
        lblLearnMore.setStyle(.txt)
        lblLearnMore.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        lblLearnMore.textColor = UIColor.gGreenMatrix()
        btnFaceID.setStyle(.primary)
        lblInfoCredentials.setStyle(.txtCard)
        btnLater.setStyle(.inline)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    func dismiss(_ action: QRUnlockSuccessAlertAction) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: {
                self.delegate?.onTap(action)
            })
        })
    }

    @IBAction func btnLearnMore(_ sender: Any) {
        dismiss(.learnMore)
    }
    @IBAction func btnFaceID(_ sender: Any) {
        dismiss(.faceID)
    }
    @IBAction func btnLater(_ sender: Any) {
        dismiss(.later)
    }
}
