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

        if viewModel.tx.isLightning {
            btnTxId.isHidden = true
            if let message = viewModel.sendTransactionSuccess.message {
                lblAddress.text = message
            } else {
                lblAddress.isHidden = true
            }
            // btnShare.isHidden = sendTransactionSuccess?.url?.isEmpty ?? true
            btnShare.isHidden = true // never show
        } else {
            btnTxId.setTitle("\("id_transaction_id".localized):", for: .normal)
            lblAddress.text = viewModel.sendTransactionSuccess.txHash
            btnShare.setTitle("id_share_link".localized, for: .normal)
        }
    }

    func setStyle() {
        cardView.setStyle(.alert)
        lblTitle.setStyle(.subTitle)
        btnTxId.setStyle(.inlineGray)
        lblAddress.setStyle(.txtBigger)
        btnDone.setStyle(.primary)
        btnShare.setStyle(.outlined)
        lblHint.setStyle(.txt)
        let hint = NSMutableAttributedString(string: "You have just transferred \(viewModel.total ?? "")")
        hint.setColor(color: UIColor.gGrayTxt(), forText: "You have just transferred")
        lblHint.attributedText = hint
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    @IBAction func btnTxId(_ sender: Any) {
        if viewModel.tx.isLightning {
            if let message = viewModel.sendTransactionSuccess.message {
                UIPasteboard.general.string = message
            }
        } else {
            UIPasteboard.general.string = viewModel.sendTransactionSuccess.txHash
        }
        DropAlert().info(message: "id_copied_to_clipboard".localized, delay: 1.0)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @IBAction func btnDone(_ sender: Any) {
        viewModel.onClose()
    }

    @IBAction func btnShare(_ sender: Any) {
        viewModel.onShare()
    }
}
