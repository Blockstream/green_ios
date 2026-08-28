import Foundation
import UIKit

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

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var btnClose: UIButton!

    @IBOutlet weak var textFieldContainerView: UIView!
    @IBOutlet weak var feeTextField: DecimalTextField!
    @IBOutlet weak var lblRate: UILabel!

    @IBOutlet weak var btnSave: UIButton!
    @IBOutlet weak var submitBottom: NSLayoutConstraint!

    weak var delegate: DialogCustomFeeViewControllerDelegate?
    var feeRate: UInt64?
    var minFeeRate: UInt64?

    private let feeRateDecimals = 2

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
        feeTextField.maxDecimalsProvider = { [weak self] in self?.feeRateDecimals }
        feeTextField.becomeFirstResponder()
    }

    override func keyboardWillShow(notification: Notification) {
        super.keyboardWillShow(notification: notification)

        UIView.animate(withDuration: 0.5, animations: { [unowned self] in
            let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
            self.submitBottom.constant = keyboardFrame.height
        })
    }

    override func keyboardWillHide(notification: Notification) {
        super.keyboardWillHide(notification: notification)

        UIView.animate(withDuration: 0.5, animations: { [unowned self] in
            self.submitBottom.constant = 36.0
        })
    }

    func setContent() {
        lblTitle.text = "Custom Fee".localized
        lblRate.text = "sats/vB".localized
        btnSave.setTitle("id_save".localized, for: .normal)
        feeTextField.keyboardType = .decimalPad
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
        lblTitle.setStyle(.subTitle)

        btnClose.tintColor = .gGrayTxt()
        btnClose.backgroundColor = .gGrayCard()
        btnClose.cornerRadius = btnClose.bounds.height / 2

        textFieldContainerView.setStyle(.defaultStyle)
        feeTextField.font = UIFont.systemFont(ofSize: 14.0, weight: .regular)

        btnSave.setStyle(.primary)
    }

    func updateUI() {
        if feeTextField.text?.count ?? 0 > 0 {
            btnSave.setStyle(.primary)
        } else {
            btnSave.setStyle(.primaryDisabled)
        }
    }

    func validate() {
        Task {
            guard var amountText = feeTextField.text else { return }
            amountText = amountText.isEmpty ? "0" : amountText
            amountText = amountText.unlocaleFormattedString(8)
            guard let number = Double(amountText), number > 0 else { return }
            if 1000 * number >= Double(UInt64.max) { return }
            let feeRate = UInt64(1000 * number)
            if feeRate < minFeeRate ?? 0 {
                let value = Double(minFeeRate ?? 0) / 1000
                DropAlert().warning(message: String(format: "id_fee_rate_must_be_at_least_s".localized, String(format: "%.\(feeRateDecimals)f", value)))
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

    @objc func didTap(gesture: UIGestureRecognizer) {
        dismiss(.cancel, feeRate: nil)
    }

    @IBAction func feeDidChange(_ sender: Any) {
        updateUI()
    }

    @IBAction func btnSave(_ sender: Any) {
        validate()
    }

    @IBAction func btnCloseTapped(_ sender: Any) {
        dismiss(.cancel, feeRate: nil)
    }
}
