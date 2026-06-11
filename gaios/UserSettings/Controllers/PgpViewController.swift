import Foundation
import UIKit
import core


class PgpViewController: KeyboardViewController {

    @IBOutlet weak var subtitle: UILabel!
    @IBOutlet weak var textarea: UITextView!
    @IBOutlet weak var btnSave: UIButton!
    @IBOutlet weak var textareaBottomConstraint: NSLayoutConstraint?
    
    private var updateToken: NSObjectProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "id_pgp_key".localized
        subtitle.text = "id_enter_a_pgp_public_key_to_have".localized
        btnSave.setTitle("id_save".localized, for: .normal)
        btnSave.addTarget(self, action: #selector(save), for: .touchUpInside)
        setStyle()
        textarea.addDoneAndPasteButtonOnKeyboard(myAction: #selector(self.textarea.resignFirstResponder))
        Task { [weak self] in
            let pgp = try? await self?.getPgp()
           await MainActor.run {
               self?.textarea.text = pgp ?? ""
            }
        }
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
    
    func getPgp() async throws -> String? {
        if let session = WalletManager.current?.bitcoinMultisigSession, session.logged {
            return try await session.loadSettings()?.pgp
        } else if let session = WalletManager.current?.liquidMultisigSession, session.logged {
            return try await session.loadSettings()?.pgp
        } else {
            return nil
        }
    }

    func setPgp(pgp: String) async throws {
        let sessions = WalletManager.current?.activeSessions
            .filter { $0.value.gdkNetwork.multisig }
            .values
        if let sessions = sessions {
            for session in sessions {
                try await self.changeSettings(session: session, pgp: pgp)
            }
        }
    }
    func keyboardPaste(_ notification: Notification) {
        if let txt = UIPasteboard.general.string {
            textarea.text = txt
        }
    }
    func changeSettings(session: SessionManager, pgp: String) async throws {
        guard var settings = session.settings else { return }
        settings.pgp = pgp
        _ = try await session.changeSettings(settings: settings)
    }

    @objc func save(_ sender: UIButton) {
        let txt = self.textarea.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\r\n", with: "\n")

        self.startAnimating()
        Task {
            do {
                try await self.setPgp(pgp: txt)
                _ = await MainActor.run {
                    self.navigationController?.popViewController(animated: true)
                }
            } catch {
                self.showError(error)
            }
            self.stopAnimating()
        }
    }
}
