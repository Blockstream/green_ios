import Foundation
import gdk
import UIKit

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

    let viewModel: SendSuccessViewModel

    init?(coder: NSCoder, viewModel: SendSuccessViewModel) {
        self.viewModel = viewModel
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
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
    }

    func setContent() {
        lblTitle.text = "id_transaction_successful".localized
        btnDone.setTitle("id_done".localized, for: .normal)
        btnShare.setTitle("id_share_link".localized, for: .normal)
        btnShare.isHidden = viewModel.tx.isLightning
        if let message = viewModel.sendTransactionSuccess.message {
            lblAddress.text = message
            btnTxId.isHidden = true
        } else if viewModel.sendTransactionSuccess.paymentId != nil {
            btnTxId.isHidden = true
            btnShare.isHidden = true
            lblAddress.isHidden = true
        } else {
            btnTxId.isHidden = false
            btnTxId.setTitle("\("id_transaction_id".localized):", for: .normal)
            lblAddress.text = viewModel.sendTransactionSuccess.txHash
        }
    }

    func setStyle() {
        cardView.setStyle(.alert)
        lblTitle.setStyle(.subTitle)
        btnTxId.setStyle(.inlineGray)
        lblAddress.setStyle(.txtBigger)
        btnDone.setStyle(.primary)
        btnShare.setStyle(.outlined)
        lblHint.setStyle(.txtCard)
        let hint = NSMutableAttributedString(string: String(format: "You transferred %@".localized,
                                                                viewModel.total ?? ""))
        lblHint.attributedText = hint
    }

    @IBAction func btnTxId(_ sender: Any) {
        if let message = viewModel.sendTransactionSuccess.message {
            UIPasteboard.general.string = message
        } else if let paymentId = viewModel.sendTransactionSuccess.paymentId {
            UIPasteboard.general.string = paymentId
        } else if let txHash = viewModel.sendTransactionSuccess.txHash {
            UIPasteboard.general.string = txHash
        }
        DropAlert().info(message: "id_copied_to_clipboard".localized, delay: 1.0)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @IBAction func btnDone(_ sender: Any) {
        viewModel.onClose()
    }
    @IBAction func btnDismiss(_ sender: Any) {
        viewModel.onClose()
    }
    @IBAction func btnShare(_ sender: Any) {
        viewModel.onShare()
    }
}
