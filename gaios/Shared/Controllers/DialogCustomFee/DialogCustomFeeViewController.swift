import Foundation
import UIKit
import gdk

protocol DialogCustomFeeViewControllerDelegate: AnyObject {
    func didSave(fee: UInt64?)
}

enum CustomFeeAction {
    case save
    case cancel
}

class DialogCustomFeeViewController: KeyboardViewController {

    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblCustomFeeTitle: UILabel!
    @IBOutlet weak var lblCustomFeeHint: UILabel!
    @IBOutlet weak var feeTextField: UITextField!
    @IBOutlet weak var btnSave: UIButton!

    @IBOutlet weak var submitBottom: NSLayoutConstraint!

    weak var delegate: DialogCustomFeeViewControllerDelegate?
    var feeRate: UInt64?
    var account: WalletItem!

    func minFeeRate() async -> UInt64 {
        guard let estimates = try? await account.session?.getFeeEstimates() else {
            let defaultMinFee = account.gdkNetwork.liquid ? 100 : 1000
            return UInt64(defaultMinFee)
        }
        return estimates[0]
    }

    lazy var blurredView: UIView = {
        let containerView = UIView()
        let blurEffect = UIBlurEffect(style: .dark)
        let customBlurEffectView = CustomVisualEffectView(effect: blurEffect, intensity: 0.4)
        customBlurEffectView.frame = self.view.bounds

        let dimmedView = UIView()
        dimmedView.backgroundColor = .black.withAlphaComponent(0.3)
        dimmedView.frame = self.view.bounds
        containerView.addSubview(customBlurEffectView)
        containerView.addSubview(dimmedView)
        return containerView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()

        view.addSubview(blurredView)
        view.sendSubviewToBack(blurredView)

        view.alpha = 0.0
        anchorBottom.constant = -cardView.frame.size.height

        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(didSwipe))
            swipeDown.direction = .down
            self.view.addGestureRecognizer(swipeDown)
        let tapToClose = UITapGestureRecognizer(target: self, action: #selector(didTap))
            tappableBg.addGestureRecognizer(tapToClose)

        updateUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        anchorBottom.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
            self.view.layoutIfNeeded()
        }
        feeTextField.becomeFirstResponder()
        feeTextField.keyboardType = .decimalPad
        feeTextField.attributedPlaceholder = NSAttributedString(string: String(Double(feeRate ?? 1000) / 1000),
                                                                attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
    }

    func setContent() {
        lblCustomFeeTitle.text = "id_set_custom_fee_rate".localized
        lblCustomFeeHint.text = "satoshi/vbyte"
        btnSave.setTitle("id_save".localized, for: .normal)
    }

    func setStyle() {
        btnSave.cornerRadius = 4.0
        feeTextField.placeholder = ""
        feeTextField.setLeftPaddingPoints(10.0)
        feeTextField.setRightPaddingPoints(10.0)
        cardView.setStyle(.bottomsheet)
        feeTextField.setStyle(.input)
        handle.cornerRadius = 1.5
    }

    func updateUI() {
        if feeTextField.text?.count ?? 0 > 0 {
            btnSave.isEnabled = true
            btnSave.backgroundColor = UIColor.gAccent()
            btnSave.setTitleColor(.white, for: .normal)
        } else {
            btnSave.isEnabled = false
            btnSave.backgroundColor = UIColor.customBtnOff()
            btnSave.setTitleColor(UIColor.customGrayLight(), for: .normal)
        }
    }

    @objc func didTap(gesture: UIGestureRecognizer) {

        dismiss(.cancel, feeRate: nil)
    }

    override func keyboardWillShow(notification: Notification) {
        super.keyboardWillShow(notification: notification)

        UIView.animate(withDuration: 0.5, animations: { [unowned self] in
            let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
            self.submitBottom.constant = keyboardFrame.height
        })
    }

    override func keyboardWillHide(notification: Notification) {
        super.keyboardWillShow(notification: notification)
        UIView.animate(withDuration: 0.5, animations: { [unowned self] in
            self.submitBottom.constant = 36.0
        })
    }

    func validate() {
        Task {
            let minFeeRate = await self.minFeeRate()
            guard var amountText = feeTextField.text else { return }
            amountText = amountText.isEmpty ? "0" : amountText
            amountText = amountText.unlocaleFormattedString(8)
            guard let number = Double(amountText), number > 0 else { return }
            if 1000 * number >= Double(UInt64.max) { return }
            let feeRate = UInt64(1000 * number)
            if feeRate < minFeeRate {
                let value = Double(minFeeRate) / 1000
                DropAlert().warning(message: String(format: "id_fee_rate_must_be_at_least_s".localized, String(format: "%.2f", value)))
                return
            }
            dismiss(.save, feeRate: feeRate)
        }
    }

    func dismiss(_ action: CustomFeeAction, feeRate: UInt64?) {
        view.endEditing(true)
        anchorBottom.constant = -cardView.frame.size.height
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
            switch action {
            case .cancel:
                break
            case .save:
                self.delegate?.didSave(fee: feeRate)
            }
        })
    }

    @objc func didSwipe(gesture: UIGestureRecognizer) {

        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            switch swipeGesture.direction {
            case .down:
                dismiss(.cancel, feeRate: nil)
            default:
                break
            }
        }
    }

    @IBAction func feeDidChange(_ sender: Any) {
        updateUI()
    }

    @IBAction func btnSave(_ sender: Any) {
        validate()
    }
}
