
import Foundation
import UIKit
import AVFoundation

class AddressDetailViewController: UIViewController {

    var wallet: WalletItem? = nil
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var qrImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var receiveAddressLabel: UILabel!
    var amount: Double = 0
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

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = NSLocalizedString("id_address", comment: "")
        receiveAddressLabel.text = wallet?.address
        updateQRCode()
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
        backgroundView.addGestureRecognizer(tap)
    }

    @IBAction func sweepButtonClicked(_ sender: Any) {
        startScan()
    }

    @IBAction func shareButtonClicked(_ sender: Any) {
        let activityViewController = UIActivityViewController(activityItems: [wallet?.address] , applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = self.view
        self.present(activityViewController, animated: true, completion: nil)
    }

    @IBAction func copyButtonClicked(_ sender: Any) {
        UIPasteboard.general.string = receiveAddressLabel.text
    }

    func updateQRCode() {
        if (amount == 0) {
            let uri = bip21Helper.btcURIforAddress(address: (wallet?.address)!)
            qrImageView.image = QRImageGenerator.imageForTextWhite(text: uri, frame: qrImageView.frame)
        } else {
            let uri = bip21Helper.btcURIforAmnount(address:(wallet?.address)!, amount: amount)
            qrImageView.image = QRImageGenerator.imageForTextWhite(text: uri, frame: qrImageView.frame)
        }
    }

    @IBAction func generateNewAddress(_ sender: Any) {
        do {
            let address = try getSession().getReceiveAddress(subaccount: (wallet?.pointer)!)
            wallet?.address = address
            receiveAddressLabel.text = wallet?.address
            updateQRCode()
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "addressChanged"), object: nil, userInfo: ["pointer" : wallet?.pointer])
        } catch {
            print("unable to get receive address")
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

    @objc func dismiss(recognizer: UITapGestureRecognizer) {
        self.dismiss(animated: true, completion: nil)
    }

}

extension AddressDetailViewController: AVCaptureMetadataOutputObjectsDelegate {

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
                    //CALL GDK SWEEP
                }
                QRCodeReader.removeFromSuperview()
                self.captureSession.stopRunning()
                self.videoPreviewLayer?.removeFromSuperlayer()
                self.qrCodeFrameView?.frame = CGRect.zero
            }
        }
    }
}
