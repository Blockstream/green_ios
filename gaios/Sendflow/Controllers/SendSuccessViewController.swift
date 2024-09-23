import Foundation
import gdk
import UIKit

protocol SendSuccessViewControllerDelegate: AnyObject {
    func onDone()
    func onShare()
}

class SendSuccessViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnTxId: UIButton!
    @IBOutlet weak var lblAddress: UILabel!
    @IBOutlet weak var btnDone: UIButton!
    @IBOutlet weak var btnShare: UIButton!

    weak var delegate: SendSuccessViewControllerDelegate!
    var sendTransactionSuccess: SendTransactionSuccess!
    var amount: String?
    var isLightning: Bool?

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
        lblTitle.text = "Transaction successful!".localized
        btnDone.setTitle("id_done".localized, for: .normal)
        btnShare.setTitle("Share Link".localized, for: .normal)

        if isLightning ?? false {
            btnTxId.isHidden = true
            if let message = sendTransactionSuccess.message {
                lblAddress.text = message
            } else {
                lblAddress.isHidden = true
            }
            // btnShare.isHidden = sendTransactionSuccess?.url?.isEmpty ?? true
            btnShare.isHidden = true // never show
        } else {
            btnTxId.setTitle("\("id_transaction_id".localized):", for: .normal)
            lblAddress.text = sendTransactionSuccess.txHash
            btnShare.setTitle("Share Link".localized, for: .normal)
        }
    }

    func setStyle() {
        cardView.setStyle(.alert)
        lblTitle.setStyle(.subTitle)
        btnTxId.setStyle(.inlineGray)
        lblAddress.setStyle(.txtBigger)
        btnDone.setStyle(.primary)
        btnShare.setStyle(.outlined)
        btnShare.setTitleColor(.white, for: .normal)
        lblHint.setStyle(.txt)
        let hint = NSMutableAttributedString(string: "You have just transferred \(amount ?? "")")
        hint.setColor(color: UIColor.gGrayTxt(), forText: "You have just transferred")
        lblHint.attributedText = hint
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    func dismiss(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: completion)
        })
    }

    @IBAction func btnTxId(_ sender: Any) {
        if isLightning ?? false {
            if let message = sendTransactionSuccess.message {
                UIPasteboard.general.string = message
            }
        } else {
            UIPasteboard.general.string = sendTransactionSuccess.txHash
        }
        DropAlert().info(message: NSLocalizedString("id_copied_to_clipboard", comment: ""), delay: 1.0)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @IBAction func btnDone(_ sender: Any) {
        dismiss() {
            self.delegate?.onDone()
        }
    }

    @IBAction func btnShare(_ sender: Any) {
        dismiss() {
            self.delegate?.onShare()
        }
    }
}
