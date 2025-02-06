import Foundation
import UIKit

protocol DialogMnemonicLengthViewControllerDelegate: AnyObject {
    func didSelect(_ option: MnemonicLengthOption)
}

enum MnemonicLengthOption: Int {
    case _12 = 12
    case _24 = 24
}

class DialogMnemonicLengthViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnLength12: UIButton!
    @IBOutlet weak var btnLength24: UIButton!
    @IBOutlet weak var btnDismiss: UIButton!
    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    weak var delegate: DialogMnemonicLengthViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        view.alpha = 0.0

        view.accessibilityIdentifier = AccessibilityIdentifiers.DialogMnemonicLengthScreen.view
        btnLength12.accessibilityIdentifier = AccessibilityIdentifiers.DialogMnemonicLengthScreen.length12Btn
        btnLength24.accessibilityIdentifier = AccessibilityIdentifiers.DialogMnemonicLengthScreen.length24Btn
    }

    func setContent() {
        lblTitle.text = "id_new_recovery_phrase".localized
        lblHint.text = "id_choose_recovery_phrase_length".localized
        btnLength12.setTitle(String(format: "id_d_words".localized, 12), for: .normal)
        btnLength24.setTitle(String(format: "id_d_words".localized, 24), for: .normal)
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
    }

    func dismiss(_ value: MnemonicLengthOption?) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
            if let value = value {
                self.delegate?.didSelect(value)
            }
        })
    }

    @IBAction func btnLength12(_ sender: Any) {
        dismiss(._12)
    }

    @IBAction func btnLength24(_ sender: Any) {
        dismiss(._24)
    }

    @IBAction func btnDismiss(_ sender: Any) {
        dismiss(nil)
    }

}
