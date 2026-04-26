import UIKit
import AVFoundation
import core
import gdk

protocol QrScannerViewDelegate: AnyObject, Sendable {
    @MainActor func didFindCode(_ code: ScanResult)
    @MainActor func didUpdateProgress(_ progress: Float)
    @MainActor func didFailWithError(_ error: String)
    @MainActor func didChangeAuthorization(isAuthorized: Bool)
}

@MainActor
class QrScannerView: UIView {

    weak var delegate: QrScannerViewDelegate?
    private let bcurProvider = BCURProvider()
    private let cameraManager = CameraManager()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private(set) var isDismissing = false

    // UI Elements
    private let maskLayer = CAShapeLayer()
    private let cornerLayer = CAShapeLayer()
    private let scannerSize = CGSize(width: 250, height: 250)
    private let cornerLength: CGFloat = 30.0
    private var lastKnownBounds: CGRect = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupOverlay()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOverlay()
    }

    func stopScanning() {
        isDismissing = true
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
        Task {
            await setTorch(on: false)
            await bcurProvider.reset()
            await cameraManager.setDecoding(false)
            await cameraManager.stop()
        }
    }

    private func startScanningWithoutPermission() {
        Task {
            await cameraManager.setup()
            if let session = await cameraManager.session {
                await setupPreviewLayer(session: session)
            }
            setNeedsLayout()
            await cameraManager.start(self)
        }
    }

    func isScanning() async -> Bool {
        await cameraManager.isRunning
    }

    private func setupPreviewLayer(session: AVCaptureSession) async {
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = self.bounds
        self.layer.insertSublayer(preview, at: 0)
        self.previewLayer = preview
    }

    private func setupOverlay() {
        // Configure Mask Layer
        maskLayer.fillRule = .evenOdd
        maskLayer.fillColor = UIColor.black.withAlphaComponent(0.3).cgColor
        layer.addSublayer(maskLayer)
        // Configure Border View
        cornerLayer.strokeColor = UIColor.white.cgColor
        cornerLayer.lineWidth = 4.0
        cornerLayer.fillColor = UIColor.clear.cgColor
        cornerLayer.lineCap = .round
        layer.addSublayer(cornerLayer)
    }

    func prepareForDismissal() {
        isDismissing = true
        cornerLayer.opacity = 0
    }

    override func layoutSubviews() {
        guard !isDismissing else { return }
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0, bounds != lastKnownBounds else { return }
        lastKnownBounds = bounds
        previewLayer?.frame = self.bounds
        let scannerRect = CGRect(
            x: (bounds.width - scannerSize.width) / 2,
            y: (bounds.height - scannerSize.height) / 2,
            width: scannerSize.width,
            height: scannerSize.height
        )
        let path = UIBezierPath(rect: bounds)
        let holePath = UIBezierPath(roundedRect: scannerRect, cornerRadius: 12)
        path.append(holePath)
        maskLayer.path = path.cgPath
        cornerLayer.path = createCornerPath(for: scannerRect).cgPath
        if let preview = self.previewLayer, preview.connection != nil {
            let rectOfInterest = preview.metadataOutputRectConverted(fromLayerRect: scannerRect)
            if !rectOfInterest.origin.x.isNaN && !rectOfInterest.origin.y.isNaN {
                Task(priority: .userInitiated) {
                    await self.cameraManager
                        .updateRectOfInterest(rectOfInterest)
                }
            }
        }

    }

    private func createCornerPath(for rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let radius: CGFloat = 12 // Matches the mask hole radius
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(withCenter: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                    radius: radius, startAngle: .pi, endAngle: 1.5 * .pi, clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY))
        path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(withCenter: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                    radius: radius, startAngle: 1.5 * .pi, endAngle: 2 * .pi, clockwise: true)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerLength))
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerLength))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addArc(withCenter: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                    radius: radius, startAngle: 0, endAngle: 0.5 * .pi, clockwise: true)
        path.addLine(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(withCenter: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                    radius: radius, startAngle: 0.5 * .pi, endAngle: .pi, clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerLength))
        return path
    }

    func startScanningCheckPermission() {
        Task {
            isDismissing = false
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized:
                startScanningWithoutPermission()
            case .notDetermined:
                if await AVCaptureDevice.requestAccess(for: .video) {
                    startScanningWithoutPermission()
                } else {
                    delegate?.didChangeAuthorization(isAuthorized: false)
                }
            case .denied, .restricted:
                delegate?.didChangeAuthorization(isAuthorized: false)
            @unknown default: break
            }
        }
    }

    @MainActor
    private func animateSuccess() {
        cornerLayer.strokeColor = UIColor.systemGreen.cgColor
        // Create a "Pulse" animation for the line width
        let animation = CABasicAnimation(keyPath: "lineWidth")
        animation.toValue = 8.0 // Thicken the lines
        animation.duration = 0.2
        animation.autoreverses = true // Return to original width
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cornerLayer.add(animation, forKey: "pulse")
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            cornerLayer.strokeColor = UIColor.white.cgColor
        }
    }

    var isTorchAvailable: Bool {
        get async {
            if let device = await cameraManager.captureDevice {
                return device.hasTorch && device.isTorchAvailable
            }
            return false
        }
    }

    var isTorchActive: Bool {
        get async {
            await cameraManager.captureDevice?.isTorchActive == true
        }
    }

    func setTorch(on: Bool) async {
        await cameraManager.setTorch(on: on)
    }

    @MainActor
    private func flashCornersOnPartAccepted() {
        let flash = CABasicAnimation(keyPath: "strokeColor")
        flash.fromValue = UIColor.white.cgColor
        flash.toValue = UIColor.systemGreen.cgColor // Flash green for success
        flash.duration = 0.15
        flash.autoreverses = true
        flash.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cornerLayer.add(flash, forKey: "partAcceptedFlash")
    }
}

extension QrScannerView: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection) {
            guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let stringValue = metadataObject.stringValue else {
                return
            }
            Task {
                if await isDismissing {
                    return
                }
                if stringValue.lowercased().starts(with: "ur:") {
                    try? await handleAnimatedQr(stringValue)
                } else {
                    await handleStaticQr(stringValue)
                }
        }
    }

    @MainActor
    func handleStaticQr(_ code: String) {
        animateSuccess()
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        delegate?.didFindCode(ScanResult.from(result: code, bcur: nil))
    }

    func handleAnimatedQr(_ code: String) async throws {
        let shouldStart = await cameraManager.tryStartDecoding()
        if shouldStart {
            do {
                if let res = try await startBCURDecodingProcess(initialPart: code) {
                    await MainActor.run {
                        delegate?.didUpdateProgress(1)
                        delegate?.didFindCode(ScanResult.from(result: nil, bcur: res))
                    }
                }
            } catch {
                await cameraManager.setDecoding(false)
                throw error
            }
            await cameraManager.setDecoding(false)
        } else {
            await bcurProvider.provide(part: code)
        }
    }
    private func startBCURDecodingProcess(initialPart: String) async throws -> BcurDecodedData? {
        let session = WalletManager.current?.prominentSession ?? SessionManager(
            .bitcoinSS,
            newNotificationDelegate: nil
        )
        return try await session.bcurDecode(params: BcurDecodeParams(part: initialPart), bcurResolver: self)
    }
}
extension QrScannerView: BcurResolver {
    func requestData(_ info: gdk.ResolveCodeAuthData) async throws -> String {
        await MainActor.run {
            flashCornersOnPartAccepted()
            delegate?.didUpdateProgress(Float(info.estimatedProgress ?? 1) / 100)
        }
        return try await bcurProvider.requestData(info)
    }
}
