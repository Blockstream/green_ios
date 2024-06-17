import Foundation
import UIKit

protocol QRUnlockInfoAlertViewControllerDelegate: AnyObject {
    func onTap(_ action: QRUnlockInfoAlertAction)
}

enum QRUnlockInfoAlertAction {
    case learnMore
    case setup
    case alreadyUnlocked
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
        lblTitle.text = "Set a PIN via QR".localized
        lblHint.text = "Help text. QR Mode allows you to communicate with Green using Jade's camera and QR codes (instead of USB or Bluetooth). ".localized
        btnLearnMore.setTitle("Learn more here".localized, for: .normal)
        btnSetup.setTitle("Setup PIN via QR".localized, for: .normal)
        btnAlreadyUnlocked.setTitle("Already unlocked via SeedQR".localized, for: .normal)
    }

    func setStyle() {
        cardView.layer.cornerRadius = 10
        cardView.borderWidth = 1.0
        cardView.borderColor = .white.withAlphaComponent(0.05)
        lblTitle.setStyle(.titleCard)
        lblHint.setStyle(.txtCard)
        btnLearnMore.setStyle(.inline)
        btnSetup.setStyle(.primary)
        btnAlreadyUnlocked.setStyle(.inline)
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
