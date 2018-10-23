import Foundation
import UIKit
import AVFoundation

class SendBtcViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var textfield: UITextField!
    @IBOutlet weak var QRCodeReader: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var topImage: UIImageView!
    @IBOutlet weak var header: UIView!
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

        tableView.tableFooterView = UIView()
        tableView.register(nib, forCellReuseIdentifier: "walletCard")
        tableView.separatorColor = UIColor.clear
        tableView.tableHeaderView = UIView(frame: CGRect(origin: tableView.frame.origin, size: CGSize(width: 0.0, height: 18)))
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
        AccountStore.shared.getWallets(cached: true).done { (accs:Array<WalletItem>) in
            self.wallets = accs.reversed()
            self.tableView.reloadData()
        }
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isUserInteractionEnabled = true
        tableView.allowsSelection = true
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
        scan()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return 65;
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return wallets.count
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let wallet = wallets[indexPath.row]
        textfield.text = wallet.address
        updateButton()
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "walletCard", for: indexPath) as! WalletTableCell
        let a = wallets[indexPath.row]
        cell.name.text = a.name
        cell.balance.text = String.satoshiToBTC(satoshi: a.balance)
        cell.backgroundColor = UIColor.clear
        let shadowPath = UIBezierPath(rect: CGRect(x: -5,
                                                   y: -5,
                                                   width:  cell.mainContent.frame.size.width + 5,
                                                   height:  75))
        cell.mainContent.layer.masksToBounds = false
        cell.mainContent.layer.shadowColor = UIColor.black.cgColor
        cell.mainContent.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
        cell.mainContent.layer.shadowOpacity = 0.5
        cell.mainContent.layer.shadowPath = shadowPath.cgPath
        cell.mainContent.cornerRadius = 5
        cell.layer.zPosition = CGFloat(indexPath.row)
        return cell;

    }

    @objc func someAction(_ sender:UITapGestureRecognizer){

        scan()
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
                do {
                    var details = [String: Any]()
                    var toAddress = [String: Any]()
                    toAddress["address"] = uri
                    details["addressees"] = [toAddress]
                    let payload = try getSession().createTransaction(details: details)
                    //pass payload to next
                    self.captureSession.stopRunning()
                    self.videoPreviewLayer?.removeFromSuperlayer()
                    self.qrCodeFrameView?.frame = CGRect.zero
                    self.performSegue(withIdentifier: "next", sender: self)
                } catch {
                    print("something went wrong tryign to print payload")
                }
            }
        }
        //captureSession.stopRunning()
    }

}
