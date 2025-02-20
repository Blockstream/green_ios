import Foundation
import UIKit
import gdk
import core

class TwoFactorAuthViewController: KeyboardViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    @IBOutlet var placeholders: [UIView]!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var btnHelp: UIButton!
    @IBOutlet weak var btnCancel: UIButton!

    @IBOutlet weak var cardInfo: UIView!
    @IBOutlet weak var lblInfoTitle: UILabel!
    @IBOutlet weak var lblInfoHint: UILabel!
    @IBOutlet weak var btnInfoEnableCall: UIButton!
    @IBOutlet weak var btnInfoRetry: UIButton!
    @IBOutlet weak var btnInfoSupport: UIButton!

    @IBOutlet weak var icon: UIImageView!
    @IBOutlet var lblsDigit: [UILabel]!

    @IBOutlet weak var lblAttempts: UILabel!
    @IBOutlet weak var pinField: UITextField!

    private var updateToken: NSObjectProtocol?
    @IBOutlet weak var keyboardPad: NSLayoutConstraint!

    var digits: [Int] = []

    var onCancel: (() -> Void)?
    var onCode: ((String) -> Void)?
    var onEnable2faCall: (() -> Void)?

    var methodEnum: TwoFactorType?
    var commontitle = ""
    var attemptsRemaining: Int?
    var failure: Bool = false

    var enable2faCallMethod = false

    var orderedPlaceHolders: [UIView] {
        return placeholders.sorted { $0.tag < $1.tag }
    }

    var orderedLblsDigit: [UILabel] {
        return lblsDigit.sorted { $0.tag < $1.tag }
    }

    enum TwoFAAction {
        case cancel
        case code(digits: String)
        case enable2faCall
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        dismissDisabled = true
        setStyle()
        setContent()
        view.alpha = 0.0
        fill()
        cardInfo.isHidden = true

        btnInfoEnableCall.isHidden = !enable2faCallMethod

        if let method = methodEnum {
            switch method {
            case .email:
                icon.image = UIImage(named: "ic_2fa_code_email")!
            case .gauth:
                icon.image = UIImage(named: "ic_2fa_code_auth")!
            case .phone:
                icon.image = UIImage(named: "ic_2fa_code_call")!
            case .sms:
                icon.image = UIImage(named: "ic_2fa_code_sms")!
            }
        }
        pinField.addPasteButtonOnKeyboard()
        pinField.becomeFirstResponder()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateToken = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "KeyboardPaste"), object: nil, queue: .main, using: keyboardPaste)

    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let token = updateToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    func setContent() {
        lblTitle.text = commontitle
        btnHelp.setTitle("id_help".localized, for: .normal)
        btnCancel.setTitle("id_cancel".localized, for: .normal)
        lblInfoTitle.text = "Are you not receiving your 2FA code?".localized
        lblInfoHint.text = "Try again, using another 2FA method.".localized
        btnInfoEnableCall.setTitle("Enable 2FA Call method".localized, for: .normal)
        btnInfoRetry.setTitle("Try Again".localized, for: .normal)
        btnInfoSupport.setTitle("Contact Support".localized, for: .normal)
        updateAttempts()
    }

    func setStyle() {
        [cardInfo, cardView].forEach {
            $0.layer.cornerRadius = 10
            $0.borderWidth = 1.0
            $0.borderColor = UIColor.white.withAlphaComponent(0.1)
        }
        lblTitle.setStyle(.subTitle)
        btnHelp.setStyle(.inline)
        btnCancel.setStyle(.inline)
        btnCancel.setTitleColor(.white, for: .normal)
        orderedPlaceHolders.forEach {
            $0.cornerRadius = $0.frame.width / 2
        }
        lblInfoTitle.setStyle(.txtBigger)
        lblInfoHint.setStyle(.txtCard)

        [btnInfoRetry, btnInfoSupport, btnInfoEnableCall].forEach {
            $0?.setStyle(.inline)
        }
        lblAttempts.setStyle(.txtCard)
    }

    func updateAttempts() {
        lblAttempts.isHidden = true
        if let attemptsRemaining = attemptsRemaining {
            lblAttempts.text = String(format: "id_attempts_remaining_d".localized, attemptsRemaining)
            lblAttempts.isHidden = false
        } else if failure {
            lblAttempts.text = "id_invalid_twofactor_code".localized
            lblAttempts.isHidden = false
        }
    }

    func fill() {
        orderedPlaceHolders.forEach { $0.isHidden = false}
        for n in 0...5 {
            if let d = digits[safe: n] {
                orderedLblsDigit[n].text = "\(d)"
                orderedPlaceHolders[n].isHidden = true
            } else {
                orderedLblsDigit[n].text = ""
            }
        }
    }

    @objc func sendCode() {
        self.dismiss(.code(digits: (self.digits.map(String.init)).joined()))
    }

    func end() {
        if self.digits.count == 6 {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.sendCode), object: nil)
            perform(#selector(self.sendCode), with: nil, afterDelay: 0.5)
        }
    }

    func keyboardPaste(_ notification: Notification) {
        if let txt = UIPasteboard.general.string {
            if txt.isCode6Digits() {
                digits = []
                for c in txt {
                    if let n = Int("\(c)") {
                        digits.append(n)
                    }
                }
                fill()
                end()
            }
        }
    }

    func refresh() {
        cardInfo.isHidden.toggle()
        cardView.isHidden.toggle()
        btnCancel.isHidden.toggle()
    }

    func dismiss(_ action: TwoFAAction) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: {
                switch action {
                case .cancel:
                    self.onCancel?()
                case .code(let digits):
                    self.onCode?(digits)
                case .enable2faCall:
                    self.onEnable2faCall?()
                }
            })
        })
    }

    override func keyboardWillShow(notification: Notification) {
        super.keyboardWillShow(notification: notification)

        UIView.animate(withDuration: 0.5, animations: { [unowned self] in
            let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
            self.keyboardPad.constant = keyboardFrame.height
        })
    }

    @IBAction func btnHelp(_ sender: Any) {
        refresh()
    }

    @IBAction func btnCancel(_ sender: Any) {
        dismiss(.cancel)
    }

    @IBAction func textdidChange(_ sender: Any) {
        if let str = pinField.text {
            digits = []
            for c in str {
                if let d = Int(String(c)) {
                    digits.append(d)
                }
            }
        }
        fill()
        end()
    }

    @IBAction func btnInfoEnableCall(_ sender: Any) {
        dismiss(.enable2faCall)
    }

    @IBAction func btnInfoRetry(_ sender: Any) {
        dismiss(.cancel)
    }

    @IBAction func btnInfoSupport(_ sender: Any) {
        let request = ZendeskErrorRequest(
            network: .bitcoinMS,
            shareLogs: true,
            screenName: "2FA"
        )
        showOpenSupportUrl(request)
        dismiss(.cancel)
    }
}

extension TwoFactorAuthViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let maxLength = 6
        let currentString = (textField.text ?? "") as NSString
        let newString = currentString.replacingCharacters(in: range, with: string)

        return newString.count <= maxLength
    }
}
