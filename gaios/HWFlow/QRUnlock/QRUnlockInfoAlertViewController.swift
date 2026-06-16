import Foundation
import UIKit

protocol QRUnlockInfoAlertViewControllerDelegate: AnyObject {
    func onTap(_ action: QRUnlockInfoAlertAction)
}

enum QRUnlockInfoAlertAction {
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
    @IBOutlet weak var lblAvailable: UILabel!
    
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
        lblTitle.text = "QR Air-Gapped Mode".localized
        lblHint.text = "QR Mode allows you to communicate with the Blockstream app using Jade's camera and QR codes (instead of Bluetooth).".localized
        btnSetup.setTitle("id_qr_pin_unlock".localized, for: .normal)
        btnAlreadyUnlocked.setTitle("My Jade is already unlocked".localized, for: .normal)
        lblAvailable.text = "Only available on Jade Plus and Jade Classic.".localized
    }

    func setStyle() {
        cardView.backgroundColor = .gGrayCardBorder()
        cardView.layer.cornerRadius = 12
        cardView.borderWidth = 1.0
        cardView.borderColor = .gBorderBold()
        lblTitle.setStyle(.titleDialog)
        lblHint.setStyle(.txtCard)
        btnSetup.setStyle(.primary)
        btnAlreadyUnlocked.setStyle(.outlined)
        lblAvailable.setStyle(.txtSmaller)
        lblAvailable.textColor = .gGrayTxt()
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
    @IBAction func btnSetup(_ sender: Any) {
        dismiss(.setup)
    }
    @IBAction func btnAlreadyUnlocked(_ sender: Any) {
        dismiss(.alreadyUnlocked)
    }
}
