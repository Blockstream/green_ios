import Foundation
import UIKit
import core

protocol DialogRecoveryHelpViewControllerDelegate: AnyObject {
    func didTapHelpCenter()
    func didCancel()
}

enum DialogRecoveryAction {
    case helpCenter
    case cancel
}

class DialogRecoveryHelpViewController: KeyboardViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var lblDesc1: UILabel!

    @IBOutlet weak var btnHelpCenter: UIButton!
    @IBOutlet weak var btnDismiss: UIButton!
    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    weak var delegate: DialogRecoveryHelpViewControllerDelegate?

    var buttonConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.alpha = 0.0

        setContent()
        setStyle()

        AnalyticsManager.shared.recordView(.help)
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)

        btnHelpCenter.cornerRadius = 4.0
        btnHelpCenter.backgroundColor = UIColor.gAccent()
        btnHelpCenter.setTitleColor(.white, for: .normal)
    }

    func setContent() {
        lblTitle.text = "id_help".localized
        lblHint.text = "id_i_typed_all_my_recovery_phrase".localized
        btnHelpCenter.setTitle("id_visit_the_blockstream_help".localized, for: .normal)
        lblDesc1.text = "id_1_double_check_all_of_your".localized
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
    }

    func dismiss(_ action: DialogRecoveryAction) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
            switch action {
            case .cancel:
                self.delegate?.didCancel()
            case .helpCenter:
                self.delegate?.didTapHelpCenter()
            }
        })
    }

    @IBAction func btnHelpCenter(_ sender: Any) {
        dismiss(.helpCenter)
    }

    @IBAction func btnDismiss(_ sender: Any) {
        dismiss(.cancel)
    }

}
