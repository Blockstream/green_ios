import Foundation
import core
import UIKit

protocol EnableBiometricsDialogViewControllerDelegate: AnyObject {
    func onEnableBioAction(_ action: EnableBiometricsDialogAction)
}

enum EnableBiometricsDialogAction {
    case bio
    case jadeRequired
}

class EnableBiometricsDialogViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var lblHint2: UILabel!
    @IBOutlet weak var btnBio: UIButton!
    @IBOutlet weak var imgBio: UIImageView!
    @IBOutlet weak var btnConnection: UIButton!

    weak var delegate: EnableBiometricsDialogViewControllerDelegate?

    init?(coder: NSCoder, delegate: EnableBiometricsDialogViewControllerDelegate?) {
        self.delegate = delegate
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setStyle()
        setContent()
        view.alpha = 0.0

        if AuthenticationTypeHandler.biometryType == .faceID {
            imgBio.image = UIImage(systemName: "faceid")
            imgBio.tintColor = .white
            btnBio.setTitle("id_enable_face_id".localized, for: .normal)
            lblTitle.text = String(format: "id_use_s_for_quick_access".localized, "id_face_id".localized)
        } else if AuthenticationTypeHandler.biometryType == .touchID {
            imgBio.image = UIImage(named: "ic_airgap_biometrics")!
            btnBio.setTitle("id_enable_touch_id".localized, for: .normal)
            lblTitle.text = String(format: "id_use_s_for_quick_access".localized, "id_touch_id".localized)
        } else {
            imgBio.image = UIImage(named: "ic_airgap_biometrics")!
            btnBio.setTitle("id_touchface_id_not_available".localized, for: .normal)
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
        lblHint.text = "Use face ID to quickly check your balance and activity without connecting Jade.".localized
        lblHint2.text = "Your keys stay on Jade, and you'll still need it to send or approve transactions.".localized
        btnConnection.setTitle("Require Jade Connection".localized, for: .normal)
    }

    func setStyle() {
        cardView.setStyle(.alert)
        lblTitle.setStyle(.titleCard)
        [lblHint, lblHint2].forEach {
            $0.setStyle(.txtCard)
        }
        btnBio.setStyle(.primary)
        btnConnection.setStyle(.outlined)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    func dismiss(_ action: EnableBiometricsDialogAction) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: {
                self.delegate?.onEnableBioAction(action)
            })
        })
    }
    @IBAction func btnBio(_ sender: Any) {
        let action: EnableBiometricsDialogAction = AuthenticationTypeHandler.biometryType != nil ? .bio : .jadeRequired
        dismiss(action)
    }
    @IBAction func btnConnection(_ sender: Any) {
        dismiss(.jadeRequired)
    }
}
