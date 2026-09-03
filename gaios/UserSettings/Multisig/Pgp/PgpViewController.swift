import Foundation
import UIKit
import core


class PgpViewController: KeyboardViewController {

    @IBOutlet weak var subtitle: UILabel!
    @IBOutlet weak var textarea: UITextView!
    @IBOutlet weak var btnSave: UIButton!
    @IBOutlet weak var textareaBottomConstraint: NSLayoutConstraint?
    
    private let viewModel: PgpViewModel

    init?(coder: NSCoder, viewModel: PgpViewModel) {
        self.viewModel = viewModel
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "id_pgp_key".localized
        subtitle.text = "id_enter_a_pgp_public_key_to_have".localized
        btnSave.setTitle("id_save".localized, for: .normal)
        btnSave.addTarget(self, action: #selector(save), for: .touchUpInside)
        setStyle()
        textarea.addDoneAndPasteButtonOnKeyboard(myAction: #selector(self.textarea.resignFirstResponder))
        textarea.text = viewModel.getPgp()
    }

    func setStyle() {
        subtitle.setStyle(.txtBold)
        subtitle.font = UIFont.systemFont(ofSize: subtitle.font.pointSize, weight: .semibold)
        btnSave.setStyle(.primary)
        textarea.setStyle(.defaultStyle)
        textarea.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textarea.becomeFirstResponder()
    }
    
    override func keyboardWillShow(notification: Notification) {
        super.keyboardWillShow(notification: notification)
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        let keyboardRect = view.convert(keyboardFrame, from: nil)
        let btnSaveTop = btnSave.frame.minY
        let desiredTextareaBottom = keyboardRect.origin.y - 12
        
        if desiredTextareaBottom < btnSaveTop - 12 {
            let newGap = btnSaveTop - desiredTextareaBottom
            UIView.animate(withDuration: 0.3) { [weak self] in
                self?.textareaBottomConstraint?.constant = newGap
                self?.view.layoutIfNeeded()
            }
        }
    }

    override func keyboardWillHide(notification: Notification) {
        super.keyboardWillHide(notification: notification)
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.textareaBottomConstraint?.constant = 12
            self?.view.layoutIfNeeded()
        }
    }
    

    @objc func save(_ sender: UIButton) {
        let txt = self.textarea.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\r\n", with: "\n")

        self.startAnimating()
        Task { [weak self] in
            do {
                try await self?.viewModel.setPgp(pgp: txt)
                _ = await MainActor.run {
                    self?.stopAnimating()
                    self?.navigationController?.popViewController(animated: true)
                }
            } catch {
                self?.stopAnimating()
                self?.showError(error.description().localized)
            }
        }
    }
}
