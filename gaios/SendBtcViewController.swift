import Foundation
import UIKit
import AVFoundation

class SendBtcViewController: UIViewController {

    @IBOutlet weak var textfield: UITextField!
    @IBOutlet weak var QRCodeReader: UIView!
    @IBOutlet weak var topImage: UIImageView!
    var prefillAmount:Double = 0
    @IBOutlet weak var bottomButton: UIButton!

    var captureSession = AVCaptureSession()
    var wallets:Array<WalletItem> = Array<WalletItem>()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?
    var wallet:WalletItem? = nil
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

    @IBAction func pasteButtonClicked(_ sender: UIButton) {
        let pasteboardString: String? = UIPasteboard.general.string
        if let theString = pasteboardString {
            print("String is \(theString)")
            textfield.text = theString
        }

    }
    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "WalletCard", bundle: nil)
        let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = topImage.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        topImage.addSubview(blurEffectView)
        textfield.attributedPlaceholder = NSAttributedString(string: "Enter Bitcoin Address",
                                                             attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        textfield.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: textfield.frame.height))
        textfield.leftViewMode = .always
        self.tabBarController?.tabBar.isHidden = true
        let gesture = UITapGestureRecognizer(target: self, action:  #selector (self.someAction (_:)))
        self.QRCodeReader.addGestureRecognizer(gesture)
        QRCodeReader.isUserInteractionEnabled = true
        navigationController?.navigationBar.tintColor = UIColor.white
        hideKeyboardWhenTappedAround()
        textfield.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        bottomButton.setTitle(NSLocalizedString("padd_amount", comment: ""), for: .normal)
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        updateButton()
    }

    func updateButton() {
        if(textfield.text != nil && textfield.text != "") {
            //bottomButton.layer.sublayers?.removeFirst()
            if ((bottomButton.layer.sublayers?.count)! == 1) {
                bottomButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
            }
            bottomButton.isUserInteractionEnabled = true
        } else {
            if ((bottomButton.layer.sublayers?.count)! > 1) {
               bottomButton.layer.sublayers?.removeFirst()
            }
            bottomButton.backgroundColor = UIColor.customTitaniumLight()
            bottomButton.isUserInteractionEnabled = false
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tabBarController?.tabBar.isHidden = true
        bottomButton.layoutIfNeeded()
        updateButton()
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        //scan()
    }

    @objc func someAction(_ sender:UITapGestureRecognizer) {
        scan()
        sender.isEnabled = false
    }

    func scan() {
        if AVCaptureDevice.authorizationStatus(for: .video) ==  .authorized {
            //already authorized
            startScan()
        } else {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                if granted {
                    //access allowed
                    self.startScan()
                } else {
                    print("fuck")
                    //Send user to settings to allow camera
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
        self.performSegue(withIdentifier: "next", sender: self)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? SendBtcDetailsViewController {
            nextController.wallet = wallet
            nextController.toAddress = textfield.text
            nextController.btcAmount = prefillAmount
            nextController.selectedType = TransactionType.BTC
        }
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
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
                print(uri)
                if (!parseBitcoinUri(uri!)) {
                    print("something went wrong tryign to print payload")
                    return;
                }
                self.captureSession.stopRunning()
                self.videoPreviewLayer?.removeFromSuperlayer()
                self.qrCodeFrameView?.frame = CGRect.zero
                self.performSegue(withIdentifier: "next", sender: self)
            }
        }
        //captureSession.stopRunning()
    }
    
    func parseBitcoinUri(_ uri: String) -> Bool {
        let blockchainInfoScheme = "bitcoin://";
        let correctScheme = "bitcoin:";
        var schemeSpecific: String?
        var amount : Double?
        var address : String?
        
        if (uri.starts(with: blockchainInfoScheme)) {
            schemeSpecific = String(uri.prefix(blockchainInfoScheme.count))
        } else if (uri.starts(with: correctScheme)) {
            schemeSpecific = String(uri.prefix(correctScheme.count))
        } else {
            address = uri
        }
        
        if ((schemeSpecific) != nil) {
            var splitted = schemeSpecific?.components(separatedBy: "?")
            if (splitted?.count == 0) {
                return false
            }
            address = splitted![0]
            if ((splitted?.count)! > 1) {
                let params = splitted![1].components(separatedBy: "&")
                for param in params {
                    let keyvalue = param.components(separatedBy: "=")
                    if (keyvalue.count > 0 && keyvalue[0] == "amount") {
                        amount = Double(keyvalue[1])
                    }
                }
            }
        }
        // check if address is valid before copy to global vars with lib Wally
        if (address == nil) {
            return false
        }
        self.textfield.text = address
        self.prefillAmount = amount!
        return true
    }

}
