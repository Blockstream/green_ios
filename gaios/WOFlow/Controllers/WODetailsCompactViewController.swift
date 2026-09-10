import UIKit
import core
import greenaddress
import Foundation

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
    private var placeholderLabel: UILabel! // Placeholder for textView

    var networks = [NetworkId]()

    override func viewDidLoad() {
        super.viewDidLoad()
        setContent()
        setStyle()
        textView.delegate = self
        textView.addDoneButtonToKeyboard(myAction: #selector(self.textView.resignFirstResponder))
        textView.textContainer.heightTracksTextView = true
        textView.isScrollEnabled = false
        // Add placeholder label
        placeholderLabel = UILabel()
        placeholderLabel.text = "Paste one or more descriptors, separated by a new line.".localized
        placeholderLabel.textColor = UIColor.lightGray.withAlphaComponent(0.6)
        placeholderLabel.font = textView.font
        placeholderLabel.numberOfLines = 2
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        bgTextView.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: bgTextView.leadingAnchor, constant: 15),
            placeholderLabel.topAnchor.constraint(equalTo: bgTextView.topAnchor, constant: 18),
            placeholderLabel.trailingAnchor.constraint(equalTo: bgTextView.trailingAnchor, constant: -15)
        ])
        updatePlaceholderVisibility()
        refresh()
    }
    func setContent() {
        lblTitle.text = "id_set_up_watchonly_wallet".localized
        lblHint1.text = "id_in_a_watchonly_wallet_your".localized
        lblHint2.text = "id_scan_or_paste_your_xpub_or".localized
        btnImport.setTitle("id_import".localized, for: .normal)
        btnFile.setTitle("id_import_from_file".localized, for: .normal)
        let attr: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.gAccent(),
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        let attributeString = NSMutableAttributedString(
            string: "id_set_up_with_username_and".localized,
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
        var keyboardFrame: CGRect = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
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

    func onImport() async {
        let input: WOImportInput
        do {
            input = try WOViewModel.validateImport(text: textView.text)
        } catch {
            showError(error.description().localized)
            return
        }
        startLoader(message: "id_logging_in".localized, scope: .login)
        let wallet = WOViewModel.newAccountSinglesig(for: input.network.gdkNetwork)
        var viewModel = WOViewModel(wallet: wallet)
        do {
            try await viewModel.importSinglesig(credentials: input.credentials, network: input.network)
            logger
                .info(
                    "--> SUCCESS: \(input.network.name()) \(viewModel.wallet.name)"
                )
            stopLoader()
            success(wallet: viewModel.wallet)
        } catch {
            logger
                .error(
                    "--> ERROR: \(input.network.name()) \(viewModel.wallet.name)"
                )
            failure(error, wallet: viewModel.wallet)
        }
    }

    @MainActor
    func success(wallet: Wallet) {
        stopLoader()
        WalletNavigator.navLogged(walletId: wallet.id)
        AnalyticsManager.shared.importWallet(wallet: wallet)
    }

    @MainActor
    func failure(_ error: Error, wallet: Wallet) {
        stopLoader()
        let prettyError = error.description().localized
        DropAlert().error(message: prettyError.localized)
        AnalyticsManager.shared.failedWalletLogin(wallet: wallet, error: error, prettyError: prettyError)
        WalletsRepository.shared.delete(for: wallet)
    }
    func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !textView.text.isEmpty
    }
    @IBAction func btnFile(_ sender: Any) {
        openDocumentPicker()
        updatePlaceholderVisibility()
    }
    @IBAction func btnPaste(_ sender: Any) {
        if let txt = UIPasteboard.general.string {
            textView.text = txt
            refresh()
            updatePlaceholderVisibility()
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    @IBAction func btnScan(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Scanner", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "QrScannerViewController") { coder in
            QrScannerViewController(coder: coder, titleText: nil, delegate: self)
        }
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: false, completion: nil)
        AnalyticsManager.shared.scanQr(wallet: nil, screen: .onBoardWOCredentials)
        updatePlaceholderVisibility()
    }
    @IBAction func btnImport(_ sender: Any) {
        Task { [weak self] in
            await self?.onImport()
            self?.updatePlaceholderVisibility()
        }
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
        updatePlaceholderVisibility()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        return true
    }
}

extension WODetailsCompactViewController: QrScannerViewControllerDelegate {
    func didScan(value: ScanResult) {
        if let result = value.result {
            textView.text = result
        } else if let descriptor = value.bcur?.descriptor {
            textView.text = descriptor
        } else if let descriptors = value.bcur?.descriptors {
            textView.text = descriptors.joined(separator: "\n")
        } else if let publicΚey = value.bcur?.publicΚey {
            textView.text = publicΚey
        }
        refresh()
        updatePlaceholderVisibility()
    }
    func didStop() {
        //
    }
}

extension WODetailsCompactViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        dismiss(animated: true)
        updatePlaceholderVisibility()
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let txt = try String(contentsOfFile: url.path, encoding: .utf8)
            let data = txt.data(using: .utf8)!
            let content = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] ?? [:]
            if let keys = WOViewModel.parseGenericJson(content), !keys.isEmpty {
                textView.text = keys.joined(separator: ", ")
            } else if let keys = WOViewModel.parseElectrumJson(content), !keys.isEmpty {
                textView.text = keys.joined(separator: ", ")
            }
            if textView.text.isEmpty {
                throw NSError(domain: "id_invalid_xpub".localized, code: 42)
            }
            refresh()
            updatePlaceholderVisibility()
        } catch {
            print(error)
            showError("id_invalid_xpub".localized)
            refresh()
            updatePlaceholderVisibility()
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        //
    }
}
extension WODetailsCompactViewController: DialogListViewControllerDelegate {
    func didSwitchAtIndex(index: Int, isOn: Bool, type: DialogType) {}

    func getNetworks(singlesig: Bool, withTestnet: Bool) -> [NetworkId] {
        if withTestnet && singlesig {
            return [.electrumMainnet, .electrumLiquid, .electrumTestnet, .electrumTestnetLiquid]
        } else if withTestnet && !singlesig {
            return [.greenMainnet, .greenLiquid, .greenTestnet, .greenTestnetLiquid]
        } else if singlesig {
            return [.electrumMainnet, .electrumLiquid]
        } else {
            return [.greenMainnet, .greenLiquid]
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
