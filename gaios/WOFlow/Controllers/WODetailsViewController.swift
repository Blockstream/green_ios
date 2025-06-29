import UIKit
import core
import gdk

class WODetailsViewController: KeyboardViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var segment: UISegmentedControl!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var bgTextView: UIView!
    @IBOutlet weak var btnPaste: UIButton!
    @IBOutlet weak var btnScan: UIButton!
    @IBOutlet weak var lblDesc: UILabel!
    @IBOutlet weak var btnImport: UIButton!
    @IBOutlet weak var lblCoda: UILabel!
    @IBOutlet weak var btnFile: UIButton!
    @IBOutlet weak var lblError: UILabel!
    private let viewModel = WOViewModel()
    var network: NetworkSecurityCase!

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()

        textView.delegate = self
        textView.addDoneButtonToKeyboard(myAction: #selector(self.textView.resignFirstResponder))
        textView.textContainer.maximumNumberOfLines = 10
        textView.textContainer.heightTracksTextView = true
        textView.isScrollEnabled = false
        refresh()
    }

    func setContent() {
        lblTitle.text = "id_watchonly_details".localized
        lblHint.text = "".localized
        segment.setTitle("id_xpub".localized, forSegmentAt: 0)
        segment.setTitle("id_descriptor".localized, forSegmentAt: 1)
        let font = UIFont.systemFont(ofSize: 14.0, weight: .medium)
        segment.setTitleTextAttributes([NSAttributedString.Key.font: font], for: .normal)
        lblCoda.text = "id_log_in_via_watchonly_to_receive".localized
        btnImport.setTitle("id_import".localized, for: .normal)
        lblError.text = "This is not a valid descriptor"
        btnFile.setTitle("id_import_from_file".localized, for: .normal)
        if network.liquid {
            segment.selectedSegmentIndex = 1
            segment.setEnabled(false, forSegmentAt: 0)
        }
    }

    func setStyle() {
        lblTitle.setStyle(.title)
        lblHint.setStyle(.txt)
        lblError.setStyle(.err)
        [lblDesc, lblCoda].forEach {
            $0?.setStyle(.txt)
            $0?.textColor = UIColor.gW40()
        }
        bgTextView.cornerRadius = 5.0
        btnImport.setStyle(.primaryDisabled)
        btnFile.setStyle(.inline)
        segment.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.white], for: .selected)
        segment.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.lightGray], for: .normal)
    }

    @objc func onTextChange() {
        refresh()
    }

    func refresh() {
        lblError.isHidden = true
        btnImport.setStyle(textView.text.count > 2 ? .primary : .primaryDisabled)

        switch segment.selectedSegmentIndex {
        case 0:
            lblDesc.text = "id_scan_or_paste_your_extended".localized
        case 1:
            lblDesc.text = "id_scan_or_paste_your_public".localized
        default:
            break
        }
    }

    func openDocumentPicker() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.text])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        documentPicker.modalPresentationStyle = .automatic
        present(documentPicker, animated: true)
    }

    @IBAction func btnFile(_ sender: Any) {
        openDocumentPicker()
    }

    @IBAction func segment(_ sender: UISegmentedControl) {
        refresh()
    }

    @IBAction func btnPaste(_ sender: Any) {
        if let txt = UIPasteboard.general.string {
            textView.text = txt
            segment.selectedSegmentIndex = txt.contains("(") ? 1 : 0
            refresh()
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @IBAction func btnScan(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogScanViewController") as? DialogScanViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            present(vc, animated: false, completion: nil)

            AnalyticsManager.shared.scanQr(account: nil, screen: .onBoardWOCredentials)
        }
    }

    @IBAction func btnImport(_ sender: Any) {
        login(for: network)
    }

    func login(for network: NetworkSecurityCase) {
        let account = viewModel.newAccountSinglesig(for: network.gdkNetwork)
        let isXpubs = segment.selectedSegmentIndex == 0
        let keys = textView.text
            .split(whereSeparator: { $0 == "\n" || $0 == " " || ($0 == ","  && isXpubs) })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " ")) }
        dismissKeyboard()
        self.startLoader(message: "id_logging_in".localized)
        let credentials = self.segment.selectedSegmentIndex == 0 ? Credentials(slip132ExtendedPubkeys: keys) : Credentials(coreDescriptors: keys)
        Task {
            do {
                try await self.viewModel.setupSinglesig(for: account, credentials: credentials)
                try await self.viewModel.loginSinglesig(for: account)
                self.stopLoader()
                success(account: account)
            } catch {
                self.stopLoader()
                failure(error, account: account)
            }
        }
    }

    @MainActor
    func success(account: Account) {
        stopLoader()
        AccountNavigator.navLogged(accountId: account.id)
        AnalyticsManager.shared.importWallet(account: account)
    }

    @MainActor
    func failure(_ error: Error, account: Account) {
        var prettyError = "id_login_failed"
        switch error {
        case TwoFactorCallError.failure(let localizedDescription):
            prettyError = localizedDescription
        case LoginError.connectionFailed:
            prettyError = "id_connection_failed"
        case LoginError.failed:
            prettyError = "id_login_failed"
        default:
            break
        }
        stopLoader()
        DropAlert().error(message: prettyError.localized)
        AnalyticsManager.shared.failedWalletLogin(account: account, error: error, prettyError: prettyError)
        WalletsRepository.shared.delete(for: account)
    }
}

extension WODetailsViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.onTextChange), object: nil)
        perform(#selector(self.onTextChange), with: nil, afterDelay: 0.5)
        refresh()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
}

extension WODetailsViewController: DialogScanViewControllerDelegate {
    func didScan(value: ScanResult, index: Int?) {
        if let result = value.result {
            textView.text = result
        } else if let descriptor = value.bcur?.descriptor {
            textView.text = descriptor
        } else if let descriptors = value.bcur?.descriptors {
            textView.text = descriptors.joined(separator: "\n")
        } else if let publicΚey = value.bcur?.publicΚey {
            textView.text = publicΚey
        }
        segment.selectedSegmentIndex = textView.text?.contains("(") ?? false ? 1 : 0
        refresh()
    }
    func didStop() {
        //
    }
}

extension WODetailsViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        dismiss(animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            // Get the contents
            let txt = try String(contentsOfFile: url.path, encoding: .utf8)
            let data = txt.data(using: .utf8)!
            let content = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] ?? [:]
            if let keys = parseGenericJson(content), !keys.isEmpty {
                textView.text = keys.joined(separator: ", ")
            } else if let keys = parseElectrumJson(content), !keys.isEmpty {
                textView.text = keys.joined(separator: ", ")
            }
            if textView.text.isEmpty {
                throw NSError(domain: "id_invalid_xpub".localized, code: 42)
            }
            refresh()
        } catch {
            print(error)
            showError("id_invalid_xpub".localized)
            refresh()
        }
    }

    func parseGenericJson(_ content: [String: Any]) -> [String]? {
        // Colcard format
        return content.compactMap { $0.value as? [String: Any] }
            .compactMap { bip -> String? in
            let name = bip?["name"] as? String
            if let name = name, let type = AccountType(rawValue: name), AccountType.allCases.contains(type) {
                let pub = bip?["_pub"] as? String
                let xpub = bip?["xpub"] as? String
                return pub ?? xpub ?? nil
            }
            return nil
        }
    }

    func parseElectrumJson(_ content: [String: Any]) -> [String]? {
        // Electrum format
        return content.filter { $0.key == "keystore" }
            .compactMap { $0.value as? [String: Any] }
            .compactMap { $0["xpub"] as? String }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        //
    }
}
