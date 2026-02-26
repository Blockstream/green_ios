import Foundation
import UIKit
import core
import lightning
import BreezSDK
import gdk

class SendFailureViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var btnCopy: UIButton!
    @IBOutlet weak var bgTextView: UIView!
    @IBOutlet weak var errorTextView: UITextView!
    @IBOutlet weak var btnAgain: UIButton!
    @IBOutlet weak var btnSupport: UIButton!

    let viewModel: SendFailureViewModel

    init?(coder: NSCoder, viewModel: SendFailureViewModel) {
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
        lblTitle.text = "id_transaction_failed".localized
        errorTextView.text = viewModel.error.description().localized
        btnAgain.setTitle("id_try_again".localized, for: .normal)
        btnSupport.setTitle("id_contact_support".localized, for: .normal)
    }

    func setStyle() {
        cardView.setStyle(.alert)
        bgTextView.cornerRadius = 4.0
        lblTitle.setStyle(.subTitle)
        btnAgain.setStyle(.primary)
        btnSupport.setStyle(.outlined)
    }

    @IBAction func btnDismiss(_ sender: Any) {
        viewModel.onDismiss()
    }

    @IBAction func btnAgain(_ sender: Any) {
        viewModel.onRetry()
    }

    @IBAction func btnSupport(_ sender: Any) {
        viewModel.onSupport()
    }

    @IBAction func btnCopy(_ sender: Any) {
        UIPasteboard.general.string = viewModel.error.description().localized
        DropAlert().info(message: "id_copied_to_clipboard".localized, delay: 1.0)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
