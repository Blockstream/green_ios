import Foundation
import UIKit

protocol QRUnlockInfoAlertViewControllerDelegate: AnyObject {
    func onTap(_ action: QRUnlockInfoAlertAction)
}

enum QRUnlockInfoAlertAction {
    case learnMore
    case setup
    case alreadyUnlocked
    case cancel
}

class QRUnlockInfoAlertViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!

    @IBOutlet weak var btnLearnMore: UIButton!
    @IBOutlet weak var btnSetup: UIButton!
    @IBOutlet weak var btnAlreadyUnlocked: UIButton!
    @IBOutlet weak var btnClose: UIButton!

    weak var delegate: QRUnlockInfoAlertViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        setStyle()
        setContent()
        view.alpha = 0.0
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
    }

    func setContent() {
        lblTitle.text = "id_qr_airgapped_mode".localized
        lblHint.text = "id_qr_mode_allows_you_to".localized
        btnLearnMore.setTitle("id_learn_more".localized, for: .normal)
        btnSetup.setTitle("id_qr_pin_unlock".localized, for: .normal)
        btnAlreadyUnlocked.setTitle("id_jade_already_unlocked".localized, for: .normal)
    }

    func setStyle() {
        cardView.setStyle(.alert)
        lblTitle.setStyle(.titleCard)
        lblHint.setStyle(.txtCard)
        btnLearnMore.setStyle(.inline)
        btnSetup.setStyle(.primary)
        btnAlreadyUnlocked.setStyle(.inlineWhite)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    func dismiss(_ action: QRUnlockInfoAlertAction) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: {
                self.delegate?.onTap(action)
            })
        })
    }

    @IBAction func btnClose(_ sender: Any) {
        dismiss(.cancel)
    }
    @IBAction func btnLearnMore(_ sender: Any) {
        dismiss(.learnMore)
    }
    @IBAction func btnSetup(_ sender: Any) {
        dismiss(.setup)
    }
    @IBAction func btnAlreadyUnlocked(_ sender: Any) {
        dismiss(.alreadyUnlocked)
    }
}
