import UIKit
import core
import gdk

class WODetailsCompactViewController: KeyboardViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint1: UILabel!
    @IBOutlet weak var lblHint2: UILabel!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var bgTextView: UIView!
    @IBOutlet weak var btnPaste: UIButton!
    @IBOutlet weak var btnScan: UIButton!
    @IBOutlet weak var btnImport: UIButton!
    @IBOutlet weak var btnFile: UIButton!
    @IBOutlet weak var lblUserPwd: UILabel!
    @IBOutlet weak var btnUserPwd: UIButton!
    @IBOutlet weak var scrollView: UIScrollView!
    var networks = [NetworkSecurityCase]()
    private let viewModel = WOViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()

        textView.delegate = self
        textView.addDoneButtonToKeyboard(myAction: #selector(self.textView.resignFirstResponder))
        textView.textContainer.heightTracksTextView = true
        textView.isScrollEnabled = false
        refresh()
    }
    func setContent() {
        lblTitle.text = "Set up Watch-only Wallet".localized
        lblHint1.text = "In a watch-only wallet, your private keys remain offline for maximum security. This allows you to safely monitor your balance, history and create addresses on the go.".localized
        lblHint2.text = "Scan or paste your xpub or descriptor to set up your watch-only wallet".localized
        btnImport.setTitle("id_import".localized, for: .normal)
        btnFile.setTitle("id_import_from_file".localized, for: .normal)
        let attr: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.gAccent(),
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        let attributeString = NSMutableAttributedString(
                string: "Set up with username and password".localized,
                attributes: attr
             )
        lblUserPwd.attributedText = attributeString
        lblUserPwd.font = UIFont.systemFont(ofSize: 15.0, weight: .medium)
    }
    func setStyle() {
        lblTitle.setStyle(.txtBigger)
        [lblHint1, lblHint2].forEach {
            $0.setStyle(.txtCard)
        }
        bgTextView.cornerRadius = 5.0
        btnImport.setStyle(.primaryDisabled)
        btnFile.setStyle(.inline)
    }
    override func keyboardWillShow(notification: Notification) {
        super.keyboardWillShow(notification: notification)

        guard let userInfo = notification.userInfo else { return }
        // swiftlint:disable force_cast
        var keyboardFrame: CGRect = (userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue
        keyboardFrame = self.view.convert(keyboardFrame, from: nil)
        var contentInset: UIEdgeInsets = scrollView.contentInset
        contentInset.bottom = keyboardFrame.size.height + 20
        scrollView.contentInset = contentInset
    }
    override func keyboardWillHide(notification: Notification) {
        let contentInset: UIEdgeInsets = UIEdgeInsets.zero
        scrollView.contentInset = contentInset
        super.keyboardWillHide(notification: notification)
    }
    @objc func onTextChange() {
        refresh()
    }
    func refresh() {
        btnImport.setStyle(textView.text.count > 2 ? .primary : .primaryDisabled)
    }

    func openDocumentPicker() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.text])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        documentPicker.modalPresentationStyle = .automatic
        present(documentPicker, animated: true)
    }

    func onImport() {
        //        let account = viewModel.newAccountSinglesig(for: network.gdkNetwork)
        //        let isXpubs = segment.selectedSegmentIndex == 0
        //        let keys = textView.text
        //            .split(whereSeparator: { $0 == "\n" || $0 == " " || ($0 == ","  && isXpubs) })
        //            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " ")) }
        //        dismissKeyboard()
        //        self.startLoader(message: "id_logging_in".localized)
        //        let credentials = self.segment.selectedSegmentIndex == 0 ? Credentials(slip132ExtendedPubkeys: keys) : Credentials(coreDescriptors: keys)
        //        Task {
        //            do {
        //                try await self.viewModel.setupSinglesig(for: account, credentials: credentials)
        //                try await self.viewModel.loginSinglesig(for: account)
        //                self.stopLoader()
        //                success(account: account)
        //            } catch {
        //                self.stopLoader()
        //                failure(error, account: account)
        //            }
        //        }
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
    @IBAction func btnFile(_ sender: Any) {
        openDocumentPicker()
    }
    @IBAction func btnPaste(_ sender: Any) {
        if let txt = UIPasteboard.general.string {
            textView.text = txt
//            segment.selectedSegmentIndex = txt.contains("(") ? 1 : 0
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
        onImport()
    }
    @IBAction func btnUserPwd(_ sender: Any) {
        selectNetwork(singlesig: false)
    }
}

extension WODetailsCompactViewController: UITextViewDelegate {
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

extension WODetailsCompactViewController: DialogScanViewControllerDelegate {
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
//        segment.selectedSegmentIndex = textView.text?.contains("(") ?? false ? 1 : 0
        refresh()
    }
    func didStop() {
        //
    }
}

extension WODetailsCompactViewController: UIDocumentPickerDelegate {
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
extension WODetailsCompactViewController: DialogListViewControllerDelegate {
    func didSwitchAtIndex(index: Int, isOn: Bool, type: DialogType) {}

    func getNetworks(singlesig: Bool, withTestnet: Bool) -> [NetworkSecurityCase] {
        if withTestnet && singlesig {
            return [.bitcoinSS, .liquidSS, .testnetSS, .testnetLiquidSS]
        } else if withTestnet && !singlesig {
            return [.bitcoinMS, .liquidMS, .testnetMS, .testnetLiquidMS]
        } else if singlesig {
            return [.bitcoinSS, .liquidSS]
        } else {
            return [.bitcoinMS, .liquidMS]
        }
    }

    func selectNetwork(singlesig: Bool) {
        let testnet = AppSettings.shared.testnet
        networks = getNetworks(singlesig: singlesig, withTestnet: testnet)
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {
            let cells = networks.map {
                DialogListCellModel(
                    type: .list,
                    icon: nil,
                    title: $0.name()) }
            vc.viewModel = DialogListViewModel(title: "id_select_network".localized, type: .watchOnlyPrefs, items: cells)
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    func didSelectIndex(_ index: Int, with type: DialogType) {
        let woFlow = UIStoryboard(name: "WOFlow", bundle: nil)
        if let vc = woFlow.instantiateViewController(withIdentifier: "WOSetupViewController") as? WOSetupViewController {
            vc.network = networks[index]
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
