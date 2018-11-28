import Foundation
import UIKit
import AVFoundation

class SendBtcViewController: KeyboardViewController {

    @IBOutlet weak var textfield: UITextField!
    @IBOutlet weak var QRCodeReader: UIView!
    @IBOutlet weak var topImage: UIImageView!
    @IBOutlet weak var bottomButton: UIButton!

    var prefillAmount:Double = 0
    var uiErrorLabel: UIErrorLabel!
    var captureSession = AVCaptureSession()
    var wallets:Array<WalletItem> = Array<WalletItem>()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?
    var wallet:WalletItem? = nil
    var sweepTransaction: Bool = false
    var transaction: TransactionHelper?
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

    override func viewDidLoad() {
        super.viewDidLoad()
        // setup scanner placeholder
        let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = topImage.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        topImage.addSubview(blurEffectView)
        // setup address textedit
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

    func updateButton() {
        if(textfield.text != nil && textfield.text != "") {
            bottomButton.backgroundColor = UIColor.customMatrixGreen()
            bottomButton.isUserInteractionEnabled = true
        } else {
            bottomButton.backgroundColor = UIColor.customTitaniumLight()
            bottomButton.isUserInteractionEnabled = false
        }
    }

    @objc func someAction(_ sender:UITapGestureRecognizer) {
        if keyboardDismissGesture != nil {
            dismissKeyboard()
            return
        }
        sender.isEnabled = false
        if AVCaptureDevice.authorizationStatus(for: .video) ==  .authorized {
            // already authorized
            startScan()
        } else {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                if granted {
                    // access allowed
                    self.startScan()
                } else {
                    //Send user to settings to allow camera
                    if let url = URL(string:UIApplicationOpenSettingsURLString) {
                        if UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    }
                }
            })
        }
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
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.frame = QRCodeReader.layer.bounds
        videoPreviewLayer?.videoGravity = .resizeAspectFill
        QRCodeReader.layer.addSublayer(videoPreviewLayer!)
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
        if ((sweepTransaction && createSweepTransaction(private_key: textfield.text!)) ||
            parseBitcoinUri(textfield.text!)) {
            self.performSegue(withIdentifier: "next", sender: self)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? SendBtcDetailsViewController {
            nextController.wallet = wallet
            nextController.selectedType = TransactionType.BTC
            nextController.transaction = transaction
        }
    }
}

extension SendBtcViewController: AVCaptureMetadataOutputObjectsDelegate {

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
                let uri = metadataObj.stringValue
                var createdTx: Bool = false
                if sweepTransaction {
                    createdTx = createSweepTransaction(private_key: uri!)
                }
                else {
                    createdTx = parseBitcoinUri(uri!)
                }
                self.captureSession.stopRunning()
                self.videoPreviewLayer?.removeFromSuperlayer()
                self.qrCodeFrameView?.frame = CGRect.zero
                if createdTx {
                    self.performSegue(withIdentifier: "next", sender: self)
                    return
                }
            }
        }
        captureSession.startRunning()
    }

    func createSweepTransaction(private_key pk: String) -> Bool {
        let details: [String: Any] = [
            "addressees" : [["address" : wallet?.getAddress()]],
            "fee_rate": AccountStore.shared.getFeeRateMedium(),
            "private_key": pk
        ]
        do {
            transaction = try TransactionHelper(details)
            let error = transaction?.data["error"] as? String
            if (error != nil && !error!.isEmpty) {
                uiErrorLabel.text = NSLocalizedString(error!, comment: "")
                uiErrorLabel.isHidden = false
                return false
            }
            return true
        } catch {
            uiErrorLabel.text = NSLocalizedString(error.localizedDescription, comment: "")
            uiErrorLabel.isHidden = false
            return false
        }
    }

    func parseBitcoinUri(_ text: String) -> Bool {
        let scheme = "bitcoin:";
        let uri : String

        if (!text.starts(with: scheme)) {
            uri = scheme + text
        } else {
            uri = text
        }

        do {
            transaction = try TransactionHelper(uri)
            let error = transaction?.data["error"] as? String
            if (error != nil && !error!.isEmpty && error != "id_invalid_amount") {
                uiErrorLabel.text = NSLocalizedString(error!, comment: "")
                uiErrorLabel.isHidden = false
                return false
            }
            return true
        } catch {
            return false
        }
    }
}
