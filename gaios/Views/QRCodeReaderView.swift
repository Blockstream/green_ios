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
        if previewLayer != nil {
            layer.addSublayer(previewLayer!)
        }
        addSubview(blurEffectView)
        addSubview(borderView)
    }

    override func layoutSubviews() {
        blurEffectView.frame = frame
        previewLayer?.frame = frame

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
        if !(captureSession?.isRunning ?? true) && requestVideoAccess() ==  .authorized {
            captureSession?.startRunning()
        }
    }

    func stopScan() {
        if captureSession?.isRunning ?? false {
            captureSession?.stopRunning()
        }
    }

    func requestVideoAccess() -> AVAuthorizationStatus {
        var status: AVAuthorizationStatus = .notDetermined

        if AVCaptureDevice.authorizationStatus(for: .video) ==  .authorized {
            status = .authorized
        } else {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                if granted {
                    status = .authorized
                } else {
                    if let url = URL(string: UIApplicationOpenSettingsURLString) {
                        if UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    }
                }
            })
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
