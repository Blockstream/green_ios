import UIKit
import AVFoundation
import core


actor CameraManager {
    private(set) var session: AVCaptureSession?
    private(set) var captureDevice: AVCaptureDevice?
    private(set) var captureMetadataOutput: AVCaptureMetadataOutput?
    private(set) var isDecoding = false
    private let metadataQueue = DispatchQueue(
        label: "io.blockstream.green.scanner.metadata",
        qos: .userInteractive
    )
    /// Serializes session configuration and start/stop (blocking AV calls).
    private let sessionTasks = SerialTasks<Void>()

    func tryStartDecoding() -> Bool {
        if isDecoding { return false }
        isDecoding = true
        return true
    }

    func setDecoding(_ value: Bool) {
        isDecoding = value
    }

    func updateRectOfInterest(_ rect: CGRect) {
        captureMetadataOutput?.rectOfInterest = rect
    }

    func bestDeviceForScanning() -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            // the triple camera (Pro models).
            .builtInTripleCamera,
            // dual wide camera (Standard models iPhone 11+).
            .builtInDualWideCamera,
            // older dual camera.
            .builtInDualCamera,
            // standard wide angle camera (Older iPhones, iPads).
            .builtInWideAngleCamera
        ]
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .back
        )
        return discoverySession.devices.first
    }

    private func applyDeviceConfiguration(to device: AVCaptureDevice) throws {
        let isVirtualDevice = device.deviceType == .builtInTripleCamera
        || device.deviceType == .builtInDualWideCamera
        || device.deviceType == .builtInDualCamera
        try device.lockForConfiguration()
        // Continuous autofocus
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        // Disable smooth autofocus
        if device.isSmoothAutoFocusSupported {
            device.isSmoothAutoFocusEnabled = false
        }
        // Near-range restriction on virtual device with single-lens only
        if !isVirtualDevice, device.isAutoFocusRangeRestrictionSupported {
            device.autoFocusRangeRestriction = .near
        }
        // Minimum-focus-distance zoom compensation
        let scanningThresholdMM = 120
        if device.minimumFocusDistance > scanningThresholdMM {
            let proposedZoom = CGFloat(device.minimumFocusDistance / scanningThresholdMM)
            let appliedZoom = max(device.minAvailableVideoZoomFactor, proposedZoom)
            let losslessCeiling = device.activeFormat.videoZoomFactorUpscaleThreshold
            device.videoZoomFactor = min(appliedZoom, losslessCeiling)
        }
        device.unlockForConfiguration()
    }

    func applyBcurFrameRate(to device: AVCaptureDevice) throws {
        let targetFPS: Double = 30
        var bestFormat: AVCaptureDevice.Format?
        try device.lockForConfiguration()
        for format in device.formats {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let ranges = format.videoSupportedFrameRateRanges
            if let range = ranges.first, range.maxFrameRate >= 60, dimensions.width <= 1920 {
                bestFormat = format
            }
        }
        if let format = bestFormat {
            device.activeFormat = format
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
        }
        device.unlockForConfiguration()
    }

    func setup() async {
        // Keep a single session for the lifetime of this manager.
        if session != nil {
            return
        }
        let session = AVCaptureSession()
        session.sessionPreset = .high
        guard let videoCaptureDevice = bestDeviceForScanning() else {
            return
        }
        try? applyBcurFrameRate(to: videoCaptureDevice)
        try? applyDeviceConfiguration(to: videoCaptureDevice)
        let input = try? AVCaptureDeviceInput(device: videoCaptureDevice)
        let output = AVCaptureMetadataOutput()
        // Claim before awaiting so a re-entrant setup cannot create a second session.
        self.session = session
        self.captureDevice = videoCaptureDevice
        self.captureMetadataOutput = output
        try? await sessionTasks.add {
            if let input, session.canAddInput(input) {
                session.addInput(input)
            }
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.metadataObjectTypes = [.qr]
            }
        }
    }

    func setTorch(on: Bool) {
        guard
            let device = captureDevice,
            device.hasTorch,
            device.isTorchAvailable
        else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Could not control torch: \(error)")
        }
    }

    func start(_ objectsDelegate: (any AVCaptureMetadataOutputObjectsDelegate)?) async {
        let session = self.session
        let output = self.captureMetadataOutput
        let metadataQueue = self.metadataQueue
        try? await sessionTasks.add {
            guard let session, session.isRunning == false else { return }
            output?.setMetadataObjectsDelegate(objectsDelegate, queue: metadataQueue)
            session.startRunning()
        }
    }

    func stop() async {
        let session = self.session
        let output = self.captureMetadataOutput
        try? await sessionTasks.add {
            guard let session, session.isRunning else { return }
            output?.setMetadataObjectsDelegate(nil, queue: nil)
            session.stopRunning()
        }
    }

    var isRunning: Bool { session?.isRunning ?? false }
}
