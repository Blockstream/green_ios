import Foundation
import PromiseKit
import UIKit
import AVFoundation

class SendBtcViewController: QRCodeReaderViewController, UITextFieldDelegate {

    @IBOutlet weak var textfield: UITextField!
    @IBOutlet weak var QRCodeReader: UIView!
    @IBOutlet weak var topImage: UIImageView!
    @IBOutlet weak var bottomButton: UIButton!

    var uiErrorLabel: UIErrorLabel!
    var wallets = [WalletItem]()
    var qrCodeFrameView: UIView?
    var wallet:WalletItem? = nil
    var sweepTransaction: Bool = false
    var transaction: Transaction?

    override func viewDidLoad() {
        super.viewDidLoad()
        // setup scanner placeholder
        let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = topImage.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        topImage.addSubview(blurEffectView)

        textfield.delegate = self
        textfield.attributedPlaceholder =
            NSAttributedString(string: sweepTransaction ?
                "Enter Private Key" : NSLocalizedString("id_enter_the_address", comment: ""),
                attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        textfield.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: textfield.frame.height))
        textfield.leftViewMode = .always
        textfield.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        // setup button and error message
        bottomButton.setTitle(sweepTransaction ? NSLocalizedString("id_sweep", comment: "") : NSLocalizedString("id_add_amount", comment: ""), for: .normal)
        uiErrorLabel = UIErrorLabel(self.view)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // add tap gesture to qr scanner
        let gesture = UITapGestureRecognizer(target: self, action:  #selector (self.someAction (_:)))
        QRCodeReader.addGestureRecognizer(gesture)
        QRCodeReader.isUserInteractionEnabled = true
        // set next button
        updateButton()
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        updateButton()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        updateButton()
        return true
    }

    func updateButton() {
        if(textfield.text != nil && textfield.text != "") {
            bottomButton.applyHorizontalGradient(colours: [UIColor.customMatrixGreenDark(), UIColor.customMatrixGreen()])
            bottomButton.isUserInteractionEnabled = true
        } else {
            bottomButton.applyHorizontalGradient(colours: [UIColor.customTitaniumMedium(), UIColor.customTitaniumLight()])
            bottomButton.isUserInteractionEnabled = false
        }
    }

    @objc func someAction(_ sender: UITapGestureRecognizer) {
        if keyboardDismissGesture != nil {
            dismissKeyboard()
            return
        }
        sender.isEnabled = false
        if requestVideoAccess() ==  .authorized {
            startScan()
        }
    }

    override func startScan() {
        QRCodeReader.layoutIfNeeded()
        previewLayer.frame = QRCodeReader.layer.bounds
        QRCodeReader.layer.addSublayer(previewLayer)
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

    @IBAction func nextButtonClicked(_ sender: Any) {
        createTransaction(userInput: textfield.text!)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? SendBtcDetailsViewController {
            nextController.wallet = wallet
            nextController.selectedType = TransactionType.BTC
            nextController.transaction = transaction
        }
    }

    func createTransaction(userInput: String) {
        let details: [String: Any] = sweepTransaction ? ["private_key": userInput] : ["addressees": [["address": userInput]]]
        gaios.createTransaction(details: details).get { tx in
            self.transaction = tx
        }.done { tx in
            if !tx.error.isEmpty && tx.error != "id_invalid_amount" {
                throw TransactionError.invalid(localizedDescription: NSLocalizedString(tx.error, comment: ""))
            }
            self.performSegue(withIdentifier: "next", sender: self)
        }.catch { error in
            if let txError = (error as? TransactionError) {
                switch txError {
                case .invalid(let localizedDescription):
                    self.uiErrorLabel.text = localizedDescription
                }
            } else {
                self.uiErrorLabel.text = error.localizedDescription
            }
            self.uiErrorLabel.isHidden = false
        }
    }

    override func onQRCodeReadSuccess(result: String) {
        self.captureSession.stopRunning()
        self.previewLayer.removeFromSuperlayer()
        self.qrCodeFrameView?.frame = CGRect.zero

        createTransaction(userInput: result)
    }
}
