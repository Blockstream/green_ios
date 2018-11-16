import Foundation
import UIKit
import AVFoundation
import NVActivityIndicatorView

class EnterMnemonicsViewController: UIViewController, UITextFieldDelegate, NVActivityIndicatorViewable {

    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var qrButton: UIButton!

    let WL: [String] = getBIP39WordList()

    var textFields: Array<UITextField> = []
    var box:UIView = UIView()
    var constraint: NSLayoutConstraint? = nil
    var isKeyboardShown = false
    var suggestionView = UIView()
    var pasteView = UIView()
    var suggestion1 = UILabel()
    var suggestion2 = UILabel()
    var suggestion3 = UILabel()
    lazy var labels = [suggestion1, suggestion2, suggestion3]
    var mnemonic: [String]? = nil
    private let supportedCodeTypes = [AVMetadataObject.ObjectType.upce,
                                      AVMetadataObject.ObjectType.code39,
                                      AVMetadataObject.ObjectType.code39Mod43,
                                      AVMetadataObject.ObjectType.code93,
                                      AVMetadataObject.ObjectType.code128,
                                      AVMetadataObject.ObjectType.ean8,
                                      AVMetadataObject.ObjectType.ean13,
                                      AVMetadataObject.ObjectType.aztec,
                                      AVMetadataObject.ObjectType.pdf417,
                                      AVMetadataObject.ObjectType.itf14,
                                      AVMetadataObject.ObjectType.dataMatrix,
                                      AVMetadataObject.ObjectType.interleaved2of5,
                                      AVMetadataObject.ObjectType.qr]
    var qrCodeFrameView: UIView?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var captureSession = AVCaptureSession()
    var QRCodeReader = UIView()
    var QRBackgroundView = UIView()
    var adaptToSmallScreen = false

    override func viewDidLoad() {
        super.viewDidLoad()
        adaptToSmallScreen = self.view.frame.height == 568
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        createUI()
        NotificationCenter.default.addObserver(self, selector: #selector(EnterMnemonicsViewController.keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(EnterMnemonicsViewController.keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        hideKeyboardWhenTappedAround()
        topLabel.text = NSLocalizedString("id_enter_your_wallet_recovery_seed", comment: "")
        doneButton.setTitle(NSLocalizedString("id_done", comment: ""), for: .normal)
        createSuggestionView()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        doneButton.backgroundColor = UIColor.customTitaniumLight()
        doneButton.isUserInteractionEnabled = false
        if var pasteString = UIPasteboard.general.string {
            while(pasteString.last == " ") {
                pasteString.removeLast()
            }
            let separated = pasteString.components(separatedBy: " ")
            if(separated.count == 24) {
                mnemonic = separated
                createPasteView(mnemonics: pasteString)
                pasteView.isHidden = false
            }
        }
    }

    func createPasteView(mnemonics: String) {
        pasteView.frame = CGRect(x: 0, y: self.view.frame.height, width: self.view.frame.width, height: 100)
        pasteView.backgroundColor = UIColor.lightGray
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = UIColor.white
        label.frame = CGRect(x: 0, y: 0, width: pasteView.frame.width, height: pasteView.frame.height)
        label.text = mnemonics
        pasteView.addSubview(label)
        pasteView.isHidden = true
        pasteView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(pasteTapped))
        pasteView.addGestureRecognizer(tap)
        self.view.addSubview(pasteView)
    }

    @objc func pasteTapped(sender:UITapGestureRecognizer) {
        for index in 0..<textFields.count {
            let textField = textFields[index]
            textField.text = mnemonic?[index]
            if textField.isFirstResponder {
                textField.resignFirstResponder()
            }
        }
        doneButtonEnable()
    }

    func createSuggestionView() {
        suggestionView.frame = CGRect(x: 0, y: self.view.frame.height, width: self.view.frame.width, height: 42)
        suggestionView.backgroundColor = UIColor.lightGray
        let separator1 = UIView()
        separator1.backgroundColor = UIColor.customTitaniumLight()
        separator1.frame = CGRect(x: suggestionView.frame.width / 3, y: 0, width: 2, height: suggestionView.frame.height)
        suggestionView.addSubview(separator1)
        let separator2 = UIView()
        separator2.backgroundColor = UIColor.customTitaniumLight()
        separator2.frame = CGRect(x: suggestionView.frame.width*2 / 3, y: 0, width: 2, height: suggestionView.frame.height)
        suggestionView.addSubview(separator2)

        suggestion1.frame = CGRect(x: 0, y: 0, width: suggestionView.frame.width / 3, height: suggestionView.frame.height)
        suggestion2.frame = CGRect(x: suggestionView.frame.width / 3, y: 0, width: suggestionView.frame.width / 3, height: suggestionView.frame.height)
        suggestion3.frame = CGRect(x: suggestionView.frame.width * 2 / 3, y: 0, width: suggestionView.frame.width / 3, height: suggestionView.frame.height)

        suggestion1.textAlignment = .center
        suggestion2.textAlignment = .center
        suggestion3.textAlignment = .center

        suggestionView.addSubview(suggestion1)
        suggestionView.addSubview(suggestion2)
        suggestionView.addSubview(suggestion3)

        suggestion1.textColor = UIColor.white
        suggestion2.textColor = UIColor.white
        suggestion3.textColor = UIColor.white

        suggestion1.isUserInteractionEnabled = true
        suggestion2.isUserInteractionEnabled = true
        suggestion3.isUserInteractionEnabled = true

        let tap1 = UITapGestureRecognizer(target: self, action: #selector(suggestionTapped))
        let tap2 = UITapGestureRecognizer(target: self, action: #selector(suggestionTapped))
        let tap3 = UITapGestureRecognizer(target: self, action: #selector(suggestionTapped))

        suggestion1.addGestureRecognizer(tap1)
        suggestion2.addGestureRecognizer(tap2)
        suggestion3.addGestureRecognizer(tap3)

        suggestionView.isHidden = true
        self.view.addSubview(suggestionView)
    }

    @objc func suggestionTapped(sender:UITapGestureRecognizer) {
        let label = sender.view as! UILabel
        for index in 0..<textFields.count {
            let textField = textFields[index]
            if textField.isFirstResponder {
                textField.text = label.text
                if(index < textFields.count - 1) {
                    let next = textFields[index+1]
                    next.becomeFirstResponder()
                }
                suggestionView.isHidden = true
                break
            }
        }
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    func mergeTextFields() -> String {
        var result = ""
        for textfield in textFields {
            result += textfield.text! + " "
        }
        result = String(result.dropLast())
        return result.lowercased()
    }

    func getSuggestions(prefix: String) -> [String] {
        return WL.filter { $0.hasPrefix(prefix) }
    }

    func updateSuggestions(prefix: String) {
        let upTo = 3 // FIXME: only shows up to 3 suggestions. requires scrollview.
        let suggestions = getSuggestions(prefix: prefix)
        for i in 0..<upTo {
            labels[i].text = i < suggestions.count ? suggestions[i] : String()
        }
        suggestionView.isHidden = suggestions.isEmpty || suggestions.count > upTo
    }

    func doneButtonEnable() {
        doneButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
        doneButton.isUserInteractionEnabled = true
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        checkTextfield(textField: textField)
        if (textField.text?.count)! > 0 {
            pasteView.isHidden = true
            updateSuggestions(prefix: textField.text!)
        } else {
            suggestionView.isHidden = true
            if mnemonic != nil {
                pasteView.isHidden = false
            }
        }
        for field in textFields {
            if field.text == nil || field.text == "" {
                return
            }
        }
        doneButtonEnable()
    }

    @IBAction func doneButtonClicked(_ sender: Any) {
        let trimmedUserProvidedMnemonic = mergeTextFields()
        wrap {
            try validateMnemonic(mnemonic: trimmedUserProvidedMnemonic)
        }.done { (result: Bool) in
            if (result) {
                wrap {
                    return try getSession().login(mnemonic: trimmedUserProvidedMnemonic)
                    }.done { _ in
                        Storage.wipeAll()
                        let array = getAppDelegate().getMnemonicsArray(mnemonics: trimmedUserProvidedMnemonic)
                        getAppDelegate().setMnemonicWords(array!)
                        AppDelegate.removeKeychainData()
                        AccountStore.shared.initializeAccountStore()
                        self.performSegue(withIdentifier: "next", sender: self)
                    }.catch { error in
                        print("Login failed ", error)
                        let storyboard = UIStoryboard(name: "Main", bundle: nil)
                        let errorViewController = storyboard.instantiateViewController(withIdentifier: "error") as! NoInternetViewController
                        self.navigationController?.pushViewController(errorViewController, animated: true)
                }
            } else {
                let size = CGSize(width: 30, height: 30)
                let message = "Invalid Mnemonics"
                self.startAnimating(size, message: message, messageFont: nil, type: NVActivityIndicatorType.blank)
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
                    self.stopAnimating()
                    self.checkMnemonics()
                }
            }
        }.catch { error in

        }
    }

    func checkTextfield(textField: UITextField) {
        let suggestions = getSuggestions(prefix: textField.text!)
        textField.textColor = suggestions.isEmpty ? UIColor.red : UIColor.white
    }

    func checkMnemonics() {
        for textField in textFields {
            checkTextfield(textField: textField)
        }
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if(isKeyboardShown) {
                return
            }

            var frame = suggestionView.frame
            frame.origin.y = self.view.frame.height - keyboardSize.height - frame.height
            var frameP = pasteView.frame
            frameP.origin.y = self.view.frame.height - keyboardSize.height - frameP.height
            suggestionView.frame = frame
            pasteView.frame = frameP
            suggestionView.layoutIfNeeded()
            pasteView.layoutIfNeeded()
            isKeyboardShown = true
            if (adaptToSmallScreen) {
                let boxBottom = box.frame.origin.y + box.frame.height
                let suggestionTop = suggestionView.frame.origin.y
                if(boxBottom > suggestionTop){
                    let suggestedConstraint = constraint!.constant - (boxBottom - suggestionTop)
                    for index in 0..<textFields.count {
                        if (textFields[index].isFirstResponder) {
                            if (index > 15) {
                                constraint?.isActive = false
                                constraint = NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: topLabel, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: suggestedConstraint)
                                constraint?.isActive = true
                                topLabel.isHidden = true
                                backButton.isHidden = true
                                qrButton.isHidden = true
                            }
                        }
                    }
                }
            } else {
                let boxBottom = box.frame.origin.y + box.frame.height
                let suggestionTop = suggestionView.frame.origin.y
                if(boxBottom > suggestionTop){
                    let suggestedConstraint = constraint!.constant - (boxBottom - suggestionTop)
                    constraint?.isActive = false
                    constraint = NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: topLabel, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: suggestedConstraint)
                    constraint?.isActive = true
                }
            }
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        topLabel.isHidden = false
        backButton.isHidden = false
        qrButton.isHidden = false
        constraint?.isActive = false
        constraint = NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: topLabel, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 18)
        constraint?.isActive = true
        if(!isKeyboardShown) {
            return
        }
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            var frame = suggestionView.frame
            frame.origin.y = self.view.frame.height
            var frameP = pasteView.frame
            frameP.origin.y = self.view.frame.height
            suggestionView.frame = frame
            pasteView.frame = frameP
            isKeyboardShown = false
            print("hiding keyboard")

        }
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
        constraint = NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: topLabel, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 18)
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

    @IBAction func startQRScan(_ sender: Any) {
        startScan()
    }

    func startScan() {
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            return
        }
        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            return
        }

        captureSession = AVCaptureSession()
        if captureSession.canAddInput(captureDeviceInput) {
            captureSession.addInput(captureDeviceInput)
        }
        else {
            return
        }

        let captureMetadataOutput = AVCaptureMetadataOutput()

        if captureSession.canAddOutput(captureMetadataOutput) {
            captureSession.addOutput(captureMetadataOutput)
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = supportedCodeTypes
        }
        else {
            return
        }
        QRCodeReader.layoutIfNeeded()
        QRCodeReader.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
        self.view.addSubview(QRCodeReader)
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.frame = QRCodeReader.layer.bounds
        videoPreviewLayer?.videoGravity = .resizeAspectFill
        QRCodeReader.layer.addSublayer(videoPreviewLayer!)
        let tap = UITapGestureRecognizer(target: self, action: #selector(stopScan))
        QRCodeReader.addGestureRecognizer(tap)
        captureSession.startRunning()

        // Initialize QR Code Frame to highlight the QR code
        qrCodeFrameView = UIView()

        if let qrCodeFrameView = qrCodeFrameView {
            qrCodeFrameView.layer.borderColor = UIColor.red.cgColor
            qrCodeFrameView.layer.borderWidth = 4
            QRCodeReader.addSubview(qrCodeFrameView)
            QRCodeReader.bringSubview(toFront: qrCodeFrameView)
        }
    }

    @objc func stopScan(sender:UITapGestureRecognizer) {
        QRCodeReader.removeFromSuperview()
        self.captureSession.stopRunning()
        self.videoPreviewLayer?.removeFromSuperlayer()
        self.qrCodeFrameView?.frame = CGRect.zero
    }

}

extension EnterMnemonicsViewController: AVCaptureMetadataOutputObjectsDelegate {

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects.count == 0 {
            qrCodeFrameView?.frame = CGRect.zero
            return
        }

        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject

        if supportedCodeTypes.contains(metadataObj.type) {
            // If the found metadata is equal to the QR code metadata (or barcode) then update the status label's text and set the bounds
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
            qrCodeFrameView?.frame = barCodeObject!.bounds

            if metadataObj.stringValue != nil {
                if let scanned = metadataObj.stringValue {
                    let separated = scanned.components(separatedBy: " ")
                    if(separated.count == 24) {
                        for index in 0..<textFields.count {
                            let textField = textFields[index]
                            textField.text = separated[index]
                        }
                        doneButtonEnable()
                    }
                }
                QRCodeReader.removeFromSuperview()
                self.captureSession.stopRunning()
                self.videoPreviewLayer?.removeFromSuperlayer()
                self.qrCodeFrameView?.frame = CGRect.zero
            }
        }
        //captureSession.stopRunning()
    }
}

