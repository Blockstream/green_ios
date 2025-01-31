import Foundation
import UIKit
import core

class ContactUsViewController: KeyboardViewController {

    @IBOutlet weak var btnSubmit: UIButton!
    @IBOutlet weak var lblHint: UILabel!

    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var messageTextView: UITextView!
    @IBOutlet weak var lblCounter: UILabel!
    @IBOutlet weak var emailBox: UIView!
    @IBOutlet weak var messageBox: UIView!
    @IBOutlet weak var lblPlaceMessage: UILabel!
    @IBOutlet weak var lblLogs: UILabel!
    @IBOutlet weak var lblPubkey: UILabel!
    @IBOutlet weak var lblSettings: UILabel!
    @IBOutlet weak var lblTor: UILabel!
    @IBOutlet weak var btnLogs: UIButton!
    @IBOutlet weak var btnPubkey: UIButton!
    @IBOutlet weak var btnSettings: UIButton!
    @IBOutlet weak var btnTor: UIButton!
    @IBOutlet weak var iconLogs: UIImageView!
    @IBOutlet weak var iconPubkey: UIImageView!
    @IBOutlet weak var iconSettings: UIImageView!
    @IBOutlet weak var iconTor: UIImageView!
    @IBOutlet weak var btnScreenRecord: UIButton!
    @IBOutlet weak var btnScreenshot: UIButton!
    @IBOutlet weak var btnGallery: UIButton!
    @IBOutlet weak var modalBar: UIView!
    @IBOutlet weak var lblModalTitle: UILabel!
    @IBOutlet weak var torCheckbox: UIView!
    @IBOutlet weak var btnCopy: UIButton!
    
    var request: ZendeskErrorRequest!

    var imgUnchecked: UIImage {
        return UIImage(named: "ic_checkbox_off")!
    }
    var imgChecked: UIImage {
        return UIImage(named: "ic_checkbox_on")!
    }
    var torAllow: Bool = false
    var torEnabled: Bool {
        return AppSettings.shared.gdkSettings?.tor ?? false
    }
    let limit = 1000

    var isValid: Bool {
        if torEnabled {
            if torAllow == false {
                return false
            }
        }
        return messageTextView.text.count > 3 && (emailField.text ?? "").isValidEmailAddr()
    }
    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        torCheckbox.isHidden = !torEnabled
        emailField.delegate = self
        messageTextView.delegate = self
        updateState()
    }

    func updateState() {
        lblCounter.text = "\(messageTextView.text.count)/\(limit)"
        lblPlaceMessage.isHidden = messageTextView.text.count > 0
        btnSubmit.setStyle(isValid ? .primary : .primaryDisabled)
        iconLogs.image = request.shareLogs ? imgChecked : imgUnchecked
        iconPubkey.image = request.shareKeys ? imgChecked : imgUnchecked
        iconSettings.image = request.shareSettings ? imgChecked : imgUnchecked
        iconTor.image = torAllow ? imgChecked : imgUnchecked
    }

    func setContent() {
        title = "Contact Us".localized
        lblModalTitle.text = "Contact Us".localized
        lblHint.text = "Please be as detailed as possible when describing the issue.".localized
        btnSubmit.setTitle("id_submit".localized, for: .normal)
        emailField.attributedPlaceholder = NSAttributedString(string: "Email address".localized, attributes: [NSAttributedString.Key.foregroundColor: UIColor.white.withAlphaComponent(0.4)])
        lblPlaceMessage.text = "Issue description".localized
        lblLogs.text = "id_share_logs".localized
        lblTor.text = "I understand that asking for support through Tor will reduce my anonymity".localized
        lblPubkey.text = "Share pubkey/descriptors".localized
        lblSettings.text = "Share App Settings".localized
        btnScreenRecord.setTitle("Take a screen recording".localized, for: .normal)
        btnScreenshot.setTitle("Take a screenshot".localized, for: .normal)
        btnGallery.setTitle("Upload from gallery".localized, for: .normal)
        btnCopy.setTitle("id_copy_to_clipboard".localized, for: .normal)
        [btnScreenRecord, btnScreenshot, btnGallery].forEach {
            $0?.isHidden = true
        }
        btnCopy.isHidden = !Bundle.main.dev
    }

    func setStyle() {
        lblModalTitle.setStyle(.txtBigger)
        lblHint.setStyle(.txtBigger)
        lblCounter.setStyle(.txtCard)
        btnSubmit.setStyle(.primaryDisabled)
        [emailBox, messageBox].forEach {
            $0?.backgroundColor = .clear
            $0?.cornerRadius = 5.0
            $0?.borderWidth = 1.0
            $0?.borderColor = .white.withAlphaComponent(0.1)
        }
        [lblPlaceMessage].forEach {
            $0?.setStyle(.txt)
            $0?.textColor = UIColor.gW40()
        }
        [btnScreenRecord, btnScreenshot, btnGallery, btnCopy].forEach {
            $0?.setStyle(.outlinedWhite)
        }
        emailField.addDoneButtonToKeyboard(myAction: #selector(self.emailField.resignFirstResponder))
        messageTextView.addDoneButtonToKeyboard(myAction: #selector(self.messageTextView.resignFirstResponder))
    }

    override func viewDidAppear(_ animated: Bool) {

        updateState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        modalBar.isHidden = !self.isBeingPresented
    }

    override func keyboardWillShow(notification: Notification) {
        super.keyboardWillShow(notification: notification)
    }

    override func keyboardWillHide(notification: Notification) {
        super.keyboardWillShow(notification: notification)
    }

    @IBAction func btnCopy(_ sender: Any) {
        startAnimating()
        UIPasteboard.general.string = self.request.logs
        stopAnimating()
        DropAlert().warning(message: NSLocalizedString("id_copied_to_clipboard", comment: ""), delay: 2.0)
    }
    
    @IBAction func btnSubmit(_ sender: Any) {
        request.email = emailField.text
        request.message = messageTextView.text
        Task {
            startAnimating()
            let res = await Task.detached(priority: .background) {
                try await ZendeskSdk.shared.submitNewTicket(req: self.request)
            }.result
            stopAnimating()
            switch res {
            case .success:
                let viewModel = AlertViewModel(title: "Support Request Created".localized,
                                               hint: "You will receive an email from Blockstream Support")
                let storyboard = UIStoryboard(name: "Alert", bundle: nil)
                if let vc = storyboard.instantiateViewController(withIdentifier: "AlertViewController") as? AlertViewController {
                    vc.viewModel = viewModel
                    vc.delegate = self
                    vc.modalPresentationStyle = .overFullScreen
                    self.present(vc, animated: false, completion: nil)
                }
            case .failure(let error):
                DropAlert().error(message: error.localizedDescription)
            }
        }
    }

    func close() {
        if let navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    @IBAction func textFieldDidChange(_ sender: Any) {
        updateState()
    }
    @IBAction func btnLogs(_ sender: Any) {
        request.shareLogs.toggle()
        updateState()
    }
    @IBAction func btnTor(_ sender: Any) {
        torAllow.toggle()
        updateState()
    }
    @IBAction func btnPukey(_ sender: Any) {
        request.shareKeys.toggle()
        updateState()
    }
    @IBAction func btnSettings(_ sender: Any) {
        request.shareSettings.toggle()
        updateState()
    }
    @IBAction func btnModalClose(_ sender: Any) {
        close()
    }
}

extension ContactUsViewController: UITextFieldDelegate {
    func didbeginEditing(_ textField: UITextField) {
        self.updateState()
    }
    func dideditEnding(_ textField: UITextField) {
        self.updateState()
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true}
}
extension ContactUsViewController: UITextViewDelegate {

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let newText = (textView.text as NSString).replacingCharacters(in: range, with: text)
        let numberOfChars = newText.count
        return numberOfChars <= limit
    }

    func textViewDidChange(_ textView: UITextView) {
        lblCounter.text = "\(messageTextView.text.count)/\(limit)"
        self.updateState()
    }
}
extension ContactUsViewController: AlertViewControllerDelegate {
    func onAlertOk() {
        close()
    }
}
