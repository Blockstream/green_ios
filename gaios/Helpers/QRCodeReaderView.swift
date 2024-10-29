import AVFoundation
import UIKit
import gdk
import core

protocol QRCodeReaderDelegate: AnyObject {
    func onQRCodeReadSuccess(result: ScanResult)
    func userDidGrant(_: Bool)
    func onBcurProgress(_: ResolveCodeAuthData)
}

class QRCodeReaderView: UIView {

    private let sessionQueue = DispatchQueue(label: "capture session queue", qos: .userInteractive)

    var captureSession = AVCaptureSession()
    var captureMetadataOutput: AVCaptureMetadataOutput?
    var buffer = [String]()
    var previous: String?
    var validating = false
    var session: SessionManager?

    var timer: Timer?

    var activeFrameView = UIView()
    var cFrame: CGRect {
        return CGRect(x: 0.0, y: 0.0, width: frame.width, height: frame.height)
    }

    lazy var previewLayer: AVCaptureVideoPreviewLayer? = {
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        return previewLayer
    }()

    lazy var placeholderTextView: UIView = {
        let placeholderTextView = UIView(frame: frame)
        placeholderTextView.backgroundColor = UIColor.customTitaniumDark()
        let label = UIButton(frame: CGRect(x: 36, y: 0, width: cFrame.width - 72, height: cFrame.height))
        placeholderTextView.addSubview(label)

        label.translatesAutoresizingMaskIntoConstraints = true
        label.center = CGPoint(x: placeholderTextView.bounds.midX, y: placeholderTextView.bounds.midY)
        label.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        label.setTitle(NSLocalizedString("id_please_enable_camera", comment: ""), for: .normal)
        label.setTitleColor(UIColor.customTitaniumMedium(), for: .normal)
        label.titleLabel?.adjustsFontSizeToFitWidth = false
        label.titleLabel?.numberOfLines = 0
        label.titleLabel?.textAlignment = .center
        label.backgroundColor = UIColor.customTitaniumDark()
        label.addTarget(self, action: #selector(onAllowCameraTap), for: .touchUpInside)

        return placeholderTextView
    }()

    var authorizationStatus: AVAuthorizationStatus!

    weak var delegate: QRCodeReaderDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }

    func getDevice() -> AVCaptureDevice? {

        var availDevice: AVCaptureDevice?

        if let device = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back) {
            availDevice = device
        } else if let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
            availDevice = device
        } else if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            availDevice = device
        } else {
            availDevice = AVCaptureDevice.default(for: .video)
        }
        return availDevice
    }

    private func setupSession() {
        captureSession.beginConfiguration()
        defer {
            captureSession.commitConfiguration()
        }

        guard let captureDevice = getDevice() else {
            return
        }

        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            return
        }

        guard captureSession.canAddInput(captureDeviceInput) else {
            return
        }

        captureSession.addInput(captureDeviceInput)

        captureMetadataOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(captureMetadataOutput!) else {
            return
        }

        captureSession.addOutput(captureMetadataOutput!)
        captureMetadataOutput!.setMetadataObjectsDelegate(self, queue: sessionQueue)
        captureMetadataOutput!.metadataObjectTypes = self.captureMetadataOutput!.availableMetadataObjectTypes
    }

    private func setupCaptureView() {
        if previewLayer != nil {
            layer.addSublayer(previewLayer!)

            activeFrameView.layer.borderColor = UIColor.clear.cgColor
            activeFrameView.layer.borderWidth = 3
            activeFrameView.layer.cornerRadius = 10
            addSubview(activeFrameView)
            bringSubviewToFront(activeFrameView)
        }
    }

    private func setupPlaceholderView() {
        addSubview(placeholderTextView)
    }

    private func setupView() {
        backgroundColor = UIColor.customTitaniumDark()
        requestVideoAccess(presentingViewController: nil)
        sessionQueue.async {
            if self.authorizationStatus == .authorized {

                DispatchQueue.main.async {

                    self.setupCaptureView()
                }
            } else {
                DispatchQueue.main.async {
                    self.setupPlaceholderView()
                }
            }
        }
    }

    override func layoutSubviews() {
        previewLayer?.frame = cFrame
        placeholderTextView.frame = cFrame
    }

    func startScan() {
#if !(arch(i386) || arch(x86_64))
        if !self.captureSession.isRunning && self.authorizationStatus == .authorized {
            sessionQueue.async {
                self.setupSession()
                self.captureSession.startRunning()
            }
            if let rectOfInterest = self.previewLayer?.metadataOutputRectConverted(fromLayerRect: cFrame) {
                self.captureMetadataOutput?.rectOfInterest = rectOfInterest
            }
        }
#endif
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(hideActiveFrame), userInfo: nil, repeats: true)
    }

    func isSessionNotDetermined() -> Bool {
        return authorizationStatus == .notDetermined
    }

    func isSessionAuthorized() -> Bool {
        return authorizationStatus == .authorized
    }

    func stopScan() {
#if !(arch(i386) || arch(x86_64))
        if captureSession.isRunning {
                self.captureSession.stopRunning()
        }
#endif
        hideActiveFrame()
        timer?.invalidate()
    }

    @objc func onAllowCameraTap(_ sender: Any) {
        requestVideoAccess(presentingViewController: self.findViewController())
    }

    func requestVideoAccess(presentingViewController: UIViewController?) {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

        if authorizationStatus == .notDetermined {
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                self.delegate?.userDidGrant(granted)
                if granted {
                    self.authorizationStatus = .authorized
                }
                // not authorized
                self.sessionQueue.resume()
            })
        } else if authorizationStatus == .denied {
            let alert = UIAlertController(title: NSLocalizedString("id_please_enable_camera", comment: ""), message: NSLocalizedString("id_we_use_the_camera_to_scan_qr", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("id_cancel", comment: ""), style: .cancel) { _ in })
            alert.addAction(UIAlertAction(title: NSLocalizedString("id_next", comment: ""), style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
                    }
                }
            })
            DispatchQueue.main.async {
                presentingViewController?.present(alert, animated: true, completion: nil)
            }
        }
    }
}

extension QRCodeReaderView: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {

        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else {
                return
            }
            guard let stringValue = readableObject.stringValue else {
                return
            }
            if previous ?? "" == stringValue || buffer.contains(stringValue) || stringValue.isEmpty {
                return
            }
            previous = stringValue
            buffer.append(stringValue)
            logger.info(">> append \(stringValue)")

            self.addActiveFrame(metadataObject)

            if !stringValue.uppercased().starts(with: "UR:") {
                self.delegate?.onQRCodeReadSuccess(result: ScanResult.from(result: stringValue, bcur: nil))
                previous = nil
                buffer = []
                return
            }
            Task {
                if validating == true {
                    return
                }
                do {
                    validating = true
                    var value = ""
                    if !buffer.isEmpty { value = buffer.removeFirst() }
                    logger.info(">> value \(value)")
                    if let result = try await validate(value) {
                        delegate?.onQRCodeReadSuccess(result: ScanResult.from(result: nil, bcur: result))
                        previous = nil
                        buffer = []
                        validating = false
                    }
                } catch {
                    print(error)
                    previous = nil
                    buffer = []
                    validating = false
                }
            }
        }
    }

    func addActiveFrame(_ metadataObject: AVMetadataObject) {
        if let barCodeObject = previewLayer?.transformedMetadataObject(for: metadataObject) {
            print(barCodeObject)
            let qrCodeFrame = barCodeObject.bounds
            DispatchQueue.main.async {
                self.activeFrameView.borderColor = UIColor.gGreenMatrix()
                self.activeFrameView.frame = CGRect(x: qrCodeFrame.origin.x - 3, y: qrCodeFrame.origin.y - 3, width: qrCodeFrame.width + 6, height: qrCodeFrame.height + 6)
            }
        } else {
            DispatchQueue.main.async {
                self.activeFrameView.isHidden = true
            }
        }
    }

    @objc func hideActiveFrame() {
        DispatchQueue.main.async {
            self.activeFrameView.borderColor = .clear
        }
    }

    func validate(_ text: String) async throws -> BcurDecodedData? {
        if session == nil {
            session = SessionManager(NetworkSecurityCase.bitcoinSS.gdkNetwork)
        }
        return try await session?.bcurDecode(params: BcurDecodeParams(part: text), bcurResolver: self)
    }

}
extension QRCodeReaderView: BcurResolver {
    func requestData(_ info: gdk.ResolveCodeAuthData) async throws -> String {
        delegate?.onBcurProgress(info)
        for _ in 0...10*5 {
            if !buffer.isEmpty {
                let value = buffer.removeFirst()
                return value
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        validating = false
        throw TwoFactorCallError.failure(localizedDescription: "id_invalid_address".localized)
    }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}
