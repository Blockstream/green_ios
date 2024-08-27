import Foundation
import UIKit
import core
import lightning
import BreezSDK
import gdk

protocol SendFailViewControllerDelegate: AnyObject {
    func onAgain()
    func onSupport(error: Error)
}

class SendFailViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var btnCopy: UIButton!
    @IBOutlet weak var bgTextView: UIView!
    @IBOutlet weak var errorTextView: UITextView!
    @IBOutlet weak var btnAgain: UIButton!
    @IBOutlet weak var btnSupport: UIButton!

    weak var delegate: SendFailViewControllerDelegate?
    var error: Error!

    var viewModel: LTSuccessViewModel!

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
        lblTitle.text = "Transaction failed".localized
        errorTextView.text = error.description()?.localized
        btnAgain.setTitle("id_try_again".localized, for: .normal)
        btnSupport.setTitle("Contact Support".localized, for: .normal)
    }

    func setStyle() {
        cardView.layer.cornerRadius = 10
        bgTextView.cornerRadius = 4.0
        lblTitle.setStyle(.subTitle)
        btnAgain.setStyle(.primary)
        btnSupport.setStyle(.outlinedWhite)
        btnSupport.setTitleColor(UIColor.white, for: .normal)
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

    @IBAction func btnDismiss(_ sender: Any) {
        dismiss() {}
    }

    @IBAction func btnAgain(_ sender: Any) {
        dismiss() {
            self.delegate?.onAgain()
        }
    }

    @IBAction func btnSupport(_ sender: Any) {
        dismiss() {
            self.delegate?.onSupport(error: self.error)
        }
    }
    @IBAction func btnCopy(_ sender: Any) {
        UIPasteboard.general.string = error.description()?.localized
        DropAlert().info(message: NSLocalizedString("id_copied_to_clipboard", comment: ""), delay: 1.0)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
