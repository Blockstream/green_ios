import AVFoundation
import UIKit

class QRCodeReaderViewController : KeyboardViewController, AVCaptureMetadataOutputObjectsDelegate {

    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            return
        }
        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            return
        }

        captureSession = AVCaptureSession()
        guard captureSession.canAddInput(captureDeviceInput) else {
            return
        }

        captureSession.addInput(captureDeviceInput)

        let captureMetadataOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(captureMetadataOutput) else {
            return
        }

        captureSession.addOutput(captureMetadataOutput)
        captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        captureMetadataOutput.metadataObjectTypes = captureMetadataOutput.availableMetadataObjectTypes

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
    }

    override func viewWillDisappear(_ animated: Bool) {
        captureSession.stopRunning()

        super.viewWillDisappear(animated)
    }

    open func onQRCodeReadSuccess(result: String) {
    }

    func setPreviewLayerFrame(frame: CGRect) {
        previewLayer.frame = frame
    }

    func startScan() {
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }

    open func stopScan() {
        if captureSession.isRunning {
            captureSession.stopRunning()
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

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {

        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else {
                return
            }
            onQRCodeReadSuccess(result: readableObject.stringValue!)
        }
    }
}
