import UIKit
import NVActivityIndicatorView
import PromiseKit

class EnterMnemonicsViewController: QRCodeReaderViewController, SuggestionsDelegate, NVActivityIndicatorViewable {

    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var scanBarButton: UIBarButtonItem!
    @IBOutlet weak var mnemonicWords: UICollectionView!

    let WL = getBIP39WordList()

    var suggestions: KeyboardSuggestions? = nil
    var mnemonic = [String](repeating: String(), count: 27)
    var QRCodeReader = UIView()
    var QRBackgroundView = UIView()
    var isScannerVisible = false
    var isPasswordProtected = false

    var currIndexPath: IndexPath? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("id_enter_your_wallet_mnemonic", comment: "")
        doneButton.setTitle(NSLocalizedString("id_done", comment: ""), for: .normal)

        mnemonicWords.delegate = self
        mnemonicWords.dataSource = self

        createSuggestionView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateDoneButton(false)
    }

    func updateDoneButton(_ enable: Bool) {
        if !enable {
            doneButton.applyHorizontalGradient(colours: [UIColor.customTitaniumMedium(), UIColor.customTitaniumLight()])
            doneButton.isUserInteractionEnabled = false
        } else {
            doneButton.applyHorizontalGradient(colours: [UIColor.customMatrixGreenDark(), UIColor.customMatrixGreen()])
            doneButton.isUserInteractionEnabled = true
        }
    }

    @objc override func keyboardWillShow(notification: NSNotification) {
        super.keyboardWillShow(notification: notification)

        let userInfo = notification.userInfo
        let keyboardFrame = userInfo?[UIKeyboardFrameEndUserInfoKey] as! CGRect
        let contentInset = UIEdgeInsetsMake(0.0, 0.0, keyboardFrame.height, 0.0)
        mnemonicWords.contentInset = contentInset
        mnemonicWords.scrollIndicatorInsets = contentInset
        suggestions!.frame = CGRect(x: 0, y: view.frame.height - keyboardFrame.height - 40, width: view.frame.width, height: 40)
    }

    @objc override func keyboardWillHide(notification: NSNotification) {
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
        mnemonic[currIndexPath!.row + currIndexPath!.section * 3] = suggestion
        mnemonicWords.reloadData()
    }

    func getMnemonicString() -> Promise<String> {
        return Promise { seal in
            seal.fulfill(mnemonic.prefix(upTo: isPasswordProtected ? 27 : 24).joined(separator: " ").lowercased())
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

    fileprivate func login() {
        enum LoginError: Error {
            case InvalidMnemonic
        }

        let bgq = DispatchQueue.global(qos: .background)

        firstly {
            getMnemonicString()
        }.get { (mnemonic: String) in
            guard validateMnemonic(mnemonic: mnemonic) else {
                throw LoginError.InvalidMnemonic
            }
        }.compactMap(on: bgq) {
            let resolver = try getSession().login(mnemonic: $0)
            let _ = try DummyResolve(call: resolver)
        }.done { _ in
            self.performSegue(withIdentifier: "next", sender: self)
        }.catch { error in
            var message = NSLocalizedString("id_login_failed", comment: "")
            if let _ = error as? LoginError {
                message = NSLocalizedString("id_invalid_mnemonic", comment: "")
            }
            self.startAnimating(message: message)
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
                self.stopAnimating()
            }
        }
    }

    @IBAction func doneButtonClicked(_ sender: Any) {
        login()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let pinController = segue.destination as? PinLoginViewController {
            pinController.setPinMode = true
            pinController.restoreMode = true
        }
    }

    func checkTextfield(textField: UITextField) {
        let suggestions = getSuggestions(prefix: textField.text!)
        textField.textColor = suggestions.isEmpty ? UIColor.red : UIColor.white
    }

    @IBAction func startQRScan(_ sender: UIBarButtonItem) {
        if !isScannerVisible {
            startScan()
        } else {
            stopScan()
        } 
    }

    @IBAction func switchChanged(_ sender: Any) {
        isPasswordProtected = (sender as! UISwitch).isOn
        mnemonicWords.reloadData()
    }

    override func startScan() {
        super.startScan()

        QRCodeReader.layoutIfNeeded()
        QRCodeReader.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
        self.view.addSubview(QRCodeReader)
        previewLayer.frame = QRCodeReader.layer.bounds
        QRCodeReader.layer.addSublayer(previewLayer)
        let tap = UITapGestureRecognizer(target: self, action: #selector(onTap))
        QRCodeReader.addGestureRecognizer(tap)

        // Initialize QR Code Frame to highlight the QR code
        qrCodeFrameView = UIView()

        if let qrCodeFrameView = qrCodeFrameView {
            qrCodeFrameView.layer.borderColor = UIColor.red.cgColor
            qrCodeFrameView.layer.borderWidth = 4
            QRCodeReader.addSubview(qrCodeFrameView)
            QRCodeReader.bringSubview(toFront: qrCodeFrameView)
        }
        // set title bar
        isScannerVisible = true
        scanBarButton.image = UIImage(named: "check")
    }

    override func stopScan() {
        QRCodeReader.removeFromSuperview()
        previewLayer.removeFromSuperlayer()

        isScannerVisible = false
        scanBarButton.image = UIImage(named: "qr")

        super.stopScan()
    }

    @objc func onTap(sender: UITapGestureRecognizer?) {
        stopScan()
    }

    override func onQRCodeReadSuccess(result: String) {
        let words = result.split(separator: " ")
        guard words.count == 24 || (isPasswordProtected && words.count == 27) else {
            return
        }

        words.enumerated().forEach { mnemonic[$0.0] = String($0.1) }
        mnemonicWords.reloadData()

        updateDoneButton(true)
        stopScan()
    }
}

extension EnterMnemonicsViewController : UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "wordCell",
                                                      for: indexPath) as! MnemonicWordCell
        cell.wordLabel.text = String(indexPath.row + indexPath.section * 3 + 1)
        cell.wordText.text = mnemonic[indexPath.row + indexPath.section * 3]
        cell.delegate = self
        return cell
    }
}

extension EnterMnemonicsViewController : UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 3
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return isPasswordProtected ? 9 : 8
    }
}

extension EnterMnemonicsViewController : UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width / 3, height: 40)
    }
}

extension EnterMnemonicsViewController : MnemonicWordCellDelegate {

    func collectionView(valueChangedIn textField: UITextField, from cell: MnemonicWordCell) {
        let text = textField.text?.isEmpty ?? true ? String() : textField.text!

        currIndexPath = mnemonicWords.indexPath(for: cell)
        mnemonic[currIndexPath!.row + currIndexPath!.section * 3] = text

        checkTextfield(textField: textField)
        if !text.isEmpty {
            updateSuggestions(prefix: textField.text!)
        } else {
            suggestions!.isHidden = true
        }
        for word in mnemonic {
            if word.isEmpty {
                return
            }
        }
        updateDoneButton(true)
    }
}
