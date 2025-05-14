import Foundation
import UIKit
import core
import gdk

class PgpViewController: KeyboardViewController {

    @IBOutlet weak var subtitle: UILabel!
    @IBOutlet weak var textarea: UITextView!
    @IBOutlet weak var btnSave: UIButton!
    private var updateToken: NSObjectProtocol?
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "id_pgp_key".localized
        subtitle.text = "id_enter_a_pgp_public_key_to_have".localized
        btnSave.setTitle("id_save".localized, for: .normal)
        btnSave.addTarget(self, action: #selector(save), for: .touchUpInside)
        setStyle()
        textarea.text = getPgp() ?? ""
        textarea.addDoneAndPasteButtonOnKeyboard(myAction: #selector(self.textarea.resignFirstResponder))
    }

    func setStyle() {
        btnSave.setStyle(.primary)
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
    func getPgp() -> String? {
        return WalletManager.current?.activeSessions.values
            .filter { !$0.gdkNetwork.electrum }
            .map { $0.settings?.pgp ?? "" }
            .filter { !$0.isEmpty }
            .first
    }

    func setPgp(pgp: String) async throws {
        let sessions = WalletManager.current?.activeSessions
            .filter { !$0.value.gdkNetwork.electrum }
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
        guard let settings = session.settings else { return }
        settings.pgp = pgp
        _ = try await session.changeSettings(settings: settings)
    }

    @objc func save(_ sender: UIButton) {
        let txt = self.textarea.text.trimmingCharacters(in: .whitespaces)
        self.startAnimating()
        Task {
            do {
                try await self.setPgp(pgp: txt)
                await MainActor.run {
                    self.navigationController?.popViewController(animated: true)
                }
            } catch {
                self.showError(error)
            }
            self.stopAnimating()
        }
    }
}
