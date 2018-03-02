//
//  QRCodeReaderViewController.swift
//  gaios
//

import AVFoundation
import UIKit

protocol QRCodeReaderData {
    func onQRCodeReadSuccess(_ qrcode: String)
    func onQRCodeReadFailure()
}

class QRCodeReaderViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var captureSession: AVCaptureSession!
    var captureVideoPreviewLayer: AVCaptureVideoPreviewLayer!

    weak var sendControllerDelegate: SendTableViewControllerScene!

    func onQRCodeReadFailure() {
        if let delegate = sendControllerDelegate {
            delegate.onQRCodeReadFailure()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black

        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            onQRCodeReadFailure()
            return
        }
        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            onQRCodeReadFailure()
            return
        }

        captureSession = AVCaptureSession()
        if captureSession.canAddInput(captureDeviceInput) {
            captureSession.addInput(captureDeviceInput)
        }
        else {
            onQRCodeReadFailure()
            return
        }

        let captureMetadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(captureMetadataOutput) {
            captureSession.addOutput(captureMetadataOutput)
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = [.qr, .ean8, .ean13, .pdf417]
        }
        else {
            onQRCodeReadFailure()
            return
        }

        captureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        captureVideoPreviewLayer.frame = view.layer.bounds
        captureVideoPreviewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(captureVideoPreviewLayer)

        captureSession.startRunning()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if captureSession?.isRunning == false {
            captureSession.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()

        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)

            sendControllerDelegate.onQRCodeReadSuccess(stringValue)
        }

        dismiss(animated: true)
    }
}
