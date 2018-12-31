import Foundation
import UIKit
import NVActivityIndicatorView
import PromiseKit

class EnterMnemonicsViewController: QRCodeReaderViewController, UITextFieldDelegate, SuggestionsDelegate, NVActivityIndicatorViewable {

    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var scanBarButton: UIBarButtonItem!

    let WL = getBIP39WordList()

    var textFields: Array<UITextField> = []
    var box:UIView = UIView()
    var constraint: NSLayoutConstraint? = nil
    var suggestions: KeyboardSuggestions? = nil
    var mnemonic: [String]? = nil
    var QRCodeReader = UIView()
    var QRBackgroundView = UIView()
    var adaptToSmallScreen = false
    var isScannerVisible = false

    override func viewDidLoad() {
        super.viewDidLoad()
        adaptToSmallScreen = self.view.frame.height == 568
        createUI()
        title = NSLocalizedString("id_enter_your_wallet_mnemonic", comment: "")
        doneButton.setTitle(NSLocalizedString("id_done", comment: ""), for: .normal)
        createSuggestionView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        doneButton.backgroundColor = UIColor.customTitaniumLight()
        doneButton.isUserInteractionEnabled = false
    }

    @objc override func keyboardWillShow(notification: NSNotification) {
        super.keyboardWillShow(notification: notification)

        let userInfo = notification.userInfo
        let keyboardFrame = userInfo?[UIKeyboardFrameEndUserInfoKey] as! CGRect
        self.suggestions!.frame = CGRect(x: 0, y: view.frame.height - keyboardFrame.height - 40, width: view.frame.width, height: 40)
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
        for index in 0..<textFields.count {
            let textField = textFields[index]
            if textField.isFirstResponder {
                textField.text = suggestion
                if(index < textFields.count - 1) {
                    let next = textFields[index+1]
                    next.becomeFirstResponder()
                }
                suggestions!.isHidden = true
                break
            }
        }
    }

    func getMnemonicString() -> Promise<String> {
        return Promise { seal in
            seal.fulfill(textFields.compactMap { $0.text! }.joined(separator: " ").lowercased())
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

    func doneButtonEnable() {
        doneButton.applyHorizontalGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
        doneButton.isUserInteractionEnabled = true
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        checkTextfield(textField: textField)
        if !(textField.text?.isEmpty ?? true) {
            updateSuggestions(prefix: textField.text!)
        } else {
            suggestions!.isHidden = true
        }
        for field in textFields {
            if field.text?.isEmpty ?? true {
                return
            }
        }
        doneButtonEnable()
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

    func checkMnemonics() {
        textFields.forEach { checkTextfield(textField: $0) }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }

    func createBlock(number: Int) -> UIView {
        let numberString = String(format: "%d", number+1) //loop start with 0, ui starts with 1
        let block:UIView = UIView()
        block.frame = CGRect(x: 0, y: 0, width: 8, height: 14)
        block.translatesAutoresizingMaskIntoConstraints = false

        let label: UILabel = UILabel()
        label.frame = CGRect(x: 0, y: 0, width: 8, height: 14)
        label.text = numberString
        label.textColor = UIColor.customMatrixGreen()
        label.translatesAutoresizingMaskIntoConstraints = false
        block.addSubview(label)
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.bottom, relatedBy: NSLayoutRelation.equal, toItem: block, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: block, attribute: NSLayoutAttribute.leading, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 14).isActive = true
        let size = label.sizeThatFits(CGSize(width: 25, height: 15))
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.lessThanOrEqual, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1, constant: size.width).isActive = true

        let textField: TextField = TextField()
        textField.frame = CGRect(x: 0, y: 0, width: 8, height: 14)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.borderStyle = .none
        textField.textColor = UIColor.white
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.spellCheckingType = .no
        textField.adjustsFontSizeToFitWidth = true
        textField.delegate = self
        textField.returnKeyType = UIReturnKeyType.done
        textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        block.addSubview(textField)
        textFields.append(textField)

        NSLayoutConstraint(item: textField, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: label, attribute: NSLayoutAttribute.trailing, multiplier: 1, constant: 5).isActive = true
        NSLayoutConstraint(item: textField, attribute: NSLayoutAttribute.trailing, relatedBy: NSLayoutRelation.equal, toItem: block, attribute: NSLayoutAttribute.trailing, multiplier: 1, constant: -5).isActive = true
        NSLayoutConstraint(item: textField, attribute: NSLayoutAttribute.bottom, relatedBy: NSLayoutRelation.equal, toItem: block, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: -1).isActive = true
        NSLayoutConstraint(item: textField, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 30).isActive = true

        let bottomLine:UIView = UIView()
        bottomLine.frame = CGRect(x: 0, y: 0, width: 8, height: 14)
        bottomLine.translatesAutoresizingMaskIntoConstraints = false
        bottomLine.backgroundColor = UIColor.customTitaniumMedium()
        block.addSubview(bottomLine)
        NSLayoutConstraint(item: bottomLine, attribute: NSLayoutAttribute.bottom, relatedBy: NSLayoutRelation.equal, toItem: block, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: bottomLine, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 1).isActive = true
        NSLayoutConstraint(item: bottomLine, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: label, attribute: NSLayoutAttribute.trailing, multiplier: 1, constant: 5).isActive = true
        NSLayoutConstraint(item: bottomLine, attribute: NSLayoutAttribute.trailing, relatedBy: NSLayoutRelation.equal, toItem: block, attribute: NSLayoutAttribute.trailing, multiplier: 1, constant: -5).isActive = true

        return block
    }

    func createUI() {
        let blockWidth = (view.frame.width - 32) / 4
        box.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
        box.translatesAutoresizingMaskIntoConstraints = false
        let rowMargin = adaptToSmallScreen ? 45 : 60
        let height = rowMargin * 6
        view.addSubview(box)
        NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: view, attribute: NSLayoutAttribute.width, multiplier: 0, constant: view.frame.width).isActive = true
        NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: CGFloat(height)).isActive = true
        constraint = NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.top, multiplier: 1, constant: 18)
        constraint!.isActive = true
        NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: view, attribute: NSLayoutAttribute.leading, multiplier: 1, constant: 0).isActive = true

        for index in 0..<24 {
            let row:Int = index / 4
            let block = createBlock(number: index)
            box.addSubview(block)

            let leadingConstant:CGFloat = CGFloat(16 + CGFloat(index % 4) * blockWidth)

            let topConstant:CGFloat = CGFloat(row * rowMargin)

            NSLayoutConstraint(item: block, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 0, constant: blockWidth).isActive = true
            NSLayoutConstraint(item: block, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 45).isActive = true
            NSLayoutConstraint(item: block, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: box, attribute: NSLayoutAttribute.leading, multiplier: 1, constant: leadingConstant).isActive = true
            NSLayoutConstraint(item: block, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: box, attribute: NSLayoutAttribute.top, multiplier: 1, constant: topConstant).isActive = true
            //add constraints tp block
        }
    }

    @IBAction func startQRScan(_ sender: UIBarButtonItem) {
        if !isScannerVisible {
            startScan()
        } else {
            stopScan()
        } 
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
        guard words.count == textFields.count else {
            return
        }

        for (word, field) in zip(words, textFields) {
            field.text = String(word)
        }

        doneButtonEnable()
        stopScan()
    }
}
