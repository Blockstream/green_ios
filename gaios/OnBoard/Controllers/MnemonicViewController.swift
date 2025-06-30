import UIKit
import core
import gdk
import greenaddress

enum MnemonicActionType {
    case recoverWallet
    case addSubaccount
}

class MnemonicViewController: KeyboardViewController, SuggestionsDelegate {

    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var mnemonicWords: UICollectionView!
    @IBOutlet weak var segmentMnemonicSize: UISegmentedControl!
    @IBOutlet weak var header: UIView!
    @IBOutlet weak var lblTitle: UILabel!

    var viewModel = OnboardViewModel()
    let WL = getBIP39WordList()

    var suggestions: KeyboardSuggestions?
    var mnemonic = [String](repeating: String(), count: 27)
    var currIndexPath: IndexPath?
    var mnemonicActionType: MnemonicActionType = .recoverWallet
    var page = 0 // analytics, mnemonic fails counter
    weak var delegate: AccountCreateRecoveryKeyDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = ""
        lblTitle.text = "id_enter_your_recovery_phrase".localized
        doneButton.setTitle("id_continue".localized, for: .normal)

        mnemonicWords.delegate = self
        mnemonicWords.dataSource = self
        updateDoneButton(false)

        createSuggestionView()
        updateNavigationItem()
        setStyle()
    }

    func setStyle() {
        if mnemonicActionType == .addSubaccount {
            segmentMnemonicSize.removeSegment(at: 2, animated: false)
        }
        segmentMnemonicSize.backgroundColor = UIColor.clear
        segmentMnemonicSize.layer.borderColor = UIColor.gAccent().cgColor
        segmentMnemonicSize.selectedSegmentTintColor = UIColor.gAccent()
        let titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.gAccent()]
        segmentMnemonicSize.setTitleTextAttributes(titleTextAttributes, for: .normal)
        let titleTextAttributes1 = [NSAttributedString.Key.foregroundColor: UIColor.white]
        segmentMnemonicSize.setTitleTextAttributes(titleTextAttributes1, for: .selected)
    }

    func updateNavigationItem() {
        let helpButton = UIButton(type: .system)
        helpButton.setImage(UIImage(named: "ic_help"), for: .normal)
        helpButton.addTarget(self, action: #selector(helpButtonTapped), for: .touchUpInside)
        let qrButton = UIButton(type: .system)
        qrButton.setImage(UIImage(named: "ic_any_asset"), for: .normal)
        qrButton.addTarget(self, action: #selector(qrButtonTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItems = [UIBarButtonItem(customView: helpButton), UIBarButtonItem(customView: qrButton)]
    }

    @objc func helpButtonTapped(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Shared", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogRecoveryHelpViewController") as? DialogRecoveryHelpViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            present(vc, animated: false, completion: nil)
        }
    }

    @objc func qrButtonTapped(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogScanViewController") as? DialogScanViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            present(vc, animated: false, completion: nil)
            AnalyticsManager.shared.scanQr(account: nil, screen: .onBoardRecovery)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        let contentInset = UIEdgeInsets.zero
        mnemonicWords.contentInset = contentInset
        mnemonicWords.scrollIndicatorInsets = contentInset
    }

    func updateDoneButton(_ enable: Bool) {
        doneButton.isEnabled = enable
        doneButton.setStyle(enable ? .primary : .primaryDisabled)
    }

    override func keyboardWillShow(notification: Notification) {
        super.keyboardWillShow(notification: notification)
        let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
        let contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: keyboardFrame.height, right: 0.0)
        mnemonicWords.contentInset = contentInset
        mnemonicWords.scrollIndicatorInsets = contentInset
        suggestions!.frame = CGRect(x: 0, y: view.frame.height - keyboardFrame.height - 40, width: view.frame.width, height: 40)
    }

    override func keyboardWillHide(notification: Notification) {
        suggestions!.isHidden = true
        super.keyboardWillHide(notification: notification)
    }

    func createSuggestionView() {
        suggestions = KeyboardSuggestions(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 40))
        suggestions!.suggestionDelegate = self
        suggestions!.isHidden = true
        view.addSubview(suggestions!)
    }

    func suggestionWasTapped(suggestion: String) {
        if let currIndexPath = currIndexPath {
            mnemonic[currIndexPath.row + currIndexPath.section * 3] = suggestion
            mnemonicWords.reloadItems(at: [currIndexPath])

            let nextRow = (currIndexPath.row + 1) % 3
            let nextSection = nextRow == 0 ? (currIndexPath.section + 1) % (numberOfSections()) : currIndexPath.section
            let nextIndexPath = IndexPath(row: nextRow, section: nextSection)
            if let cell = mnemonicWords.cellForItem(at: nextIndexPath) as? MnemonicCell {
                mnemonicWords.selectItem(at: nextIndexPath, animated: false, scrollPosition: UICollectionView.ScrollPosition.centeredVertically)
                cell.wordText.becomeFirstResponder()
                suggestions?.isHidden = true
            }
        }
    }

    func restoreDialog() {
        if self.itemsCount() == 27 {
            let alert = UIAlertController(title: "id_encryption_passphrase".localized, message: "id_please_provide_your_passphrase".localized, preferredStyle: .alert)
            alert.addTextField { textField in
                textField.keyboardType = .asciiCapable
                textField.isSecureTextEntry = true
            }
            alert.addAction(UIAlertAction(title: "id_cancel".localized, style: .cancel) { (_: UIAlertAction) in
                let mnemonic = self.mnemonic.prefix(upTo: 24).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                Task { [weak self] in
                    await self?.restoreWallet(mnemonic: mnemonic, password: nil)
                }
            })
            alert.addAction(UIAlertAction(title: "id_next".localized, style: .default) { (_: UIAlertAction) in
                let textField = alert.textFields![0]
                let mnemonic = self.mnemonic.prefix(upTo: 27).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                Task { [weak self] in await
                    self?.restoreWallet(mnemonic: mnemonic, password: textField.text!)
                }
            })
            DispatchQueue.main.async {
                self.present(alert, animated: true, completion: nil)
            }
        } else {
            let mnemonic = mnemonic.prefix(upTo: 24).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            Task { [weak self] in
                await self?.restoreWallet(mnemonic: mnemonic, password: nil)
            }
        }
    }

    func getSuggestions(prefix: String) -> [String] {
        return WL.filter { $0.hasPrefix(prefix) }
    }

    func updateSuggestions(prefix: String) {
        let words = getSuggestions(prefix: prefix)
        self.suggestions!.setSuggestions(suggestions: words)
        self.suggestions!.isHidden = words.isEmpty
    }

    func restoreWallet(mnemonic: String, password: String?) async {
        startLoader(message: "id_restoring_your_wallet".localized, isRive: true)
        let task = Task.detached { [weak self] in
            let credentials = Credentials(mnemonic: mnemonic, password: password)
            OnboardViewModel.credentials = credentials
            return try await self?.viewModel.restoreWallet(credentials: credentials, pin: nil)
        }
        switch await task.result {
        case .success(let wm):
            stopLoader()
            if let account = wm?.account {
                AccountsRepository.shared.current = account
                AccountNavigator.navLogged(accountId: account.id, isFirstLoad: false)
            }
        case .failure(let err):
            stopLoader()
            logger.error("\(err.description())")
            switch err as? AuthenticationTypeHandler.AuthError {
            case .some(.DeniedByUser):
                pushOnBoardAppAccessViewController()
            case .some:
                switch AuthenticationTypeHandler.biometryType {
                case .faceID:
                    pushOnBoardAppAccessViewController()
                default:
                    pushOnBoardAppPinViewController()
                }
            case .none:
                showError(err.description().localized)
            }
        }
    }

    func pushOnBoardAppPinViewController() {
        OnboardViewModel.flowType = .restore
        let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "OnBoardAppPinViewController") as? OnBoardAppPinViewController {
            navigationController?.pushViewController(vc, animated: true)
            return
        }
    }

    func pushOnBoardAppAccessViewController() {
        OnboardViewModel.flowType = .restore
        let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "OnBoardAppAccessViewController") as? OnBoardAppAccessViewController {
            navigationController?.pushViewController(vc, animated: true)
            return
        }
    }

    @IBAction func doneButtonClicked(_ sender: Any) {
        switch self.mnemonicActionType {
        case .recoverWallet:
            restoreDialog()
        case .addSubaccount:
            break//addSubaccount()
        }
    }

    func checkTextfield(textField: UITextField) {
        if let text = textField.text {
            let suggestions = getSuggestions(prefix: text)
            textField.textColor = !suggestions.contains(text) ? UIColor.errorRed() : UIColor.white
        }
    }

    func itemsCount() -> Int {
        if segmentMnemonicSize.selectedSegmentIndex == 2 { return 27 }
        if segmentMnemonicSize.selectedSegmentIndex == 1 { return 24 }
        return 12
    }

    func numberOfSections() -> Int {
        return itemsCount() == 27 ? 9 : (itemsCount() == 24 ? 8 : 4)
    }

    @IBAction func segmentMnemonicChange(_ sender: UISegmentedControl) {
        var limit = 0
        let index = sender.selectedSegmentIndex
        switch mnemonicActionType {
        case .recoverWallet:
            limit = index == 2 ? 27 : (index == 1 ? 24 : 12)
        case .addSubaccount:
            limit = index == 1 ? 24 : 12
        }

        mnemonic = mnemonic.enumerated().map { (i, e) in
            if i < limit { return e }
            return String()
        }

        mnemonicWords.reloadData()
        let foundEmpty = mnemonic.prefix(upTo: itemsCount()).contains(where: { $0.isEmpty })
        updateDoneButton(!foundEmpty)
    }

    @objc func onTap(sender: UITapGestureRecognizer?) { }

    func isValidCount(_ count: Int) -> Bool {
        switch mnemonicActionType {
        case .recoverWallet:
            guard count == 12 || count == 24 || count == 27 else {
                return false
            }
        case .addSubaccount:
            guard count == 12 || count == 24 else {
                return false
            }
        }
        return true
    }
}

extension MnemonicViewController {
    private func onPaste(_ result: String) {
        let words = result.split(separator: " ")
        if !isValidCount(words.count) { return }
        mnemonic = [String](repeating: String(), count: 27)

        words.enumerated().forEach { mnemonic[$0.0] = String($0.1) }
        segmentMnemonicSize.selectedSegmentIndex = words.count == 27 ? 2 : (words.count == 24 ? 1 : 0)

        mnemonicWords.reloadData()
        updateDoneButton(true)
    }
}

extension MnemonicViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "wordCell", for: indexPath) as? MnemonicCell else { fatalError("Fail to dequeue reusable cell") }
        cell.wordLabel.text = String(indexPath.row + indexPath.section * 3 + 1)
        cell.wordText.text = mnemonic[indexPath.row + indexPath.section * 3]
        checkTextfield(textField: cell.wordText)
        cell.delegate = self
        cell.wordText.accessibilityIdentifier = String(indexPath.row + indexPath.section * 3 + 1)
        return cell
    }
}

extension MnemonicViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 3
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return numberOfSections()
    }
}

extension MnemonicViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width / 3, height: 40)
    }
}

extension MnemonicViewController: MnemonicCellDelegate {

    func collectionView(valueChangedIn textField: UITextField, from cell: MnemonicCell) {
        let text = textField.text?.isEmpty ?? true ? String() : textField.text!

        currIndexPath = mnemonicWords.indexPath(for: cell)
        if currIndexPath == nil {
            return
        }

        mnemonic[currIndexPath!.row + currIndexPath!.section * 3] = text

        checkTextfield(textField: textField)
        if !text.isEmpty {
            updateSuggestions(prefix: textField.text!)
        } else {
            suggestions!.isHidden = true
        }

        if text.count >= 3 {
            let filtered = WL.filter({ $0.hasPrefix(text) })
            if filtered.count == 1 {
                if filtered.first?.count == text.count {
                    suggestionWasTapped(suggestion: text)
                }
            }
        }

        let len = mnemonic.filter { !$0.isEmpty }.count
        updateDoneButton(len == itemsCount())
    }

    func collectionView(pastedIn text: String, from cell: MnemonicCell) {
        currIndexPath = mnemonicWords.indexPath(for: cell)
        onPaste(text)
    }
}

extension MnemonicViewController: DialogRecoveryHelpViewControllerDelegate {
    func didTapHelpCenter() {
        SafeNavigationManager.shared.navigate(ExternalUrls.mnemonicNotWorking)
    }

    func didCancel() { }

}

extension MnemonicViewController: DialogScanViewControllerDelegate {
    func didScan(value: ScanResult, index: Int?) {
        onPaste(value.result ?? "")
    }
    func didStop() { }
}
