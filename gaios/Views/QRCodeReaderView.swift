import AVFoundation
import UIKit

protocol QRCodeReaderDelegate {
    func onQRCodeReadSuccess(result: String)
}

class QRCodeReaderView : UIView {

    lazy var captureSession: AVCaptureSession? = {
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            return nil
        }

        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            return nil
        }

        let captureSession = AVCaptureSession()
        guard captureSession.canAddInput(captureDeviceInput) else {
            return nil
        }

        captureSession.addInput(captureDeviceInput)

        captureMetadataOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(captureMetadataOutput!) else {
            return nil
        }

        captureSession.addOutput(captureMetadataOutput!)
        captureMetadataOutput!.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        captureMetadataOutput!.metadataObjectTypes = captureMetadataOutput!.availableMetadataObjectTypes

        return captureSession
    }()

    var captureMetadataOutput: AVCaptureMetadataOutput? = nil

    lazy var previewLayer: AVCaptureVideoPreviewLayer? = {
        guard captureSession != nil else {
            return nil
        }
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer.videoGravity = .resizeAspectFill
        return previewLayer
    }()

    lazy var blurEffectView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = frame
        blurEffectView.layer.masksToBounds = true
        blurEffectView.alpha = 0.6
        return blurEffectView
    }()

    lazy var borderView: UIView = {
        let borderView = UIView(frame: frame)
        borderView.backgroundColor = UIColor(white: 0, alpha: 0)
        borderView.borderWidth = 4
        borderView.borderColor = UIColor.red
        return borderView
    }()

    lazy var placeholderTextView: UIView = {
        let placeholderTextView = UIView(frame: frame)
        placeholderTextView.backgroundColor = UIColor.customTitaniumDark()
        let label = UIButton(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        placeholderTextView.addSubview(label)

        label.translatesAutoresizingMaskIntoConstraints = true
        label.center = CGPoint(x: placeholderTextView.bounds.midX, y: placeholderTextView.bounds.midY)
        label.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        label.setTitle("Press to allow camera access", for: .normal)
        label.setTitleColor(UIColor.customTitaniumMedium(), for: .normal)
        label.titleLabel?.adjustsFontSizeToFitWidth = true
        label.backgroundColor = UIColor.customTitaniumDark()
        label.addTarget(self, action: #selector(onAllowCameraTap), for: .touchUpInside)

        return placeholderTextView
    }()

    var delegate: QRCodeReaderDelegate? = nil

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }

    private func setupView() {
        if captureSession != nil {
            if previewLayer != nil {
                layer.addSublayer(previewLayer!)
            }
            addSubview(blurEffectView)
            addSubview(borderView)
        } else {
            addSubview(placeholderTextView)
        }
    }

    override func layoutSubviews() {
        blurEffectView.frame = frame
        previewLayer?.frame = frame
        placeholderTextView.frame = frame

        borderView.frame = createFrame(frame: frame)
        captureMetadataOutput?.rectOfInterest = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)

        let maskLayer = createMaskLayer()
        if #available(iOS 11.0, *) {
            blurEffectView.layer.mask = maskLayer
        } else {
            let maskView = UIView(frame: frame)
            maskView.backgroundColor = UIColor.clear
            maskView.layer.mask = maskLayer
            blurEffectView.mask = maskView
        }
    }

    func createBorderView(frame: CGRect) -> UIView {
        let rect = createFrame(frame: frame)
        let borderView = UIView(frame: rect)
        borderView.backgroundColor = UIColor(white: 0, alpha: 0)
        borderView.borderWidth = 4
        borderView.borderColor = UIColor.red
        return borderView
    }

    private func createMaskLayer() -> CALayer {
        let rect = createFrame(frame: frame)
        let path = UIBezierPath(rect: frame)
        let centerRectangle = UIBezierPath(rect: rect)
        path.append(centerRectangle)
        path.usesEvenOddFillRule = true

        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        maskLayer.fillRule = kCAFillRuleEvenOdd
        return maskLayer
    }

    private func createFrame(frame: CGRect) -> CGRect {
        var rect = CGRect(x: 0.0, y: 0.0, width: frame.size.width / 2, height: frame.size.width / 2)
        rect.origin.x = frame.size.width / 2 - rect.size.width / 2
        rect.origin.y = frame.size.height / 2 - rect.size.height / 2
        return rect
    }

    func startScan() {
        if captureSession != nil {
            // app has permission to use camera (default or otherwise) but may have not
            // been authorised on first install
            if !captureSession!.isRunning && requestVideoAccess(presentingViewController: nil) ==  .authorized {
                captureSession?.startRunning()
            }
        }
        // no permissions or not available. defer behaviour to parent view controller
    }

    func isCaptureSessionAvailable() -> Bool {
        return captureSession != nil
    }

    func stopScan() {
        if captureSession?.isRunning ?? false {
            captureSession?.stopRunning()
        }
    }

    @objc func onAllowCameraTap(_ sender: Any) {
        _ = requestVideoAccess(presentingViewController: self.findViewController())
    }

    func requestVideoAccess(presentingViewController: UIViewController?) -> AVAuthorizationStatus {
        var status = AVCaptureDevice.authorizationStatus(for: .video)

        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                if granted {
                    status = .authorized
                }
                // not authorised
            })
        } else if status == .denied {
            let alert = UIAlertController(title: "Allow camera access", message: NSLocalizedString("Green will restart", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("id_cancel", comment: ""), style: .cancel) { _ in })
            alert.addAction(UIAlertAction(title: NSLocalizedString("id_next", comment: ""), style: .default) { _ in
                if let url = URL(string: UIApplicationOpenSettingsURLString) {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
            })
            DispatchQueue.main.async {
                presentingViewController?.present(alert, animated: true, completion: nil)
            }
        }
        return status
    }
}

extension QRCodeReaderView : AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {

        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else {
                return
            }
            guard let stringValue = readableObject.stringValue else {
                return
            }
            delegate?.onQRCodeReadSuccess(result: stringValue)
        }
    }
}
