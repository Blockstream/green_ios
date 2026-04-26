import Foundation
import UIKit
import core
import gdk

protocol QrScannerViewControllerDelegate: AnyObject {
    func didScan(value: ScanResult)
    func didStop()
}

class QrScannerViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var qrScanView: QrScannerView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var progressView: SmoothProgressView!
    @IBOutlet weak var torchButton: UIButton!
    @IBOutlet weak var progressVerticalConstraint: NSLayoutConstraint!

    weak var delegate: QrScannerViewControllerDelegate?
    var titleText: String?

    init?(coder: NSCoder, titleText: String?, delegate: QrScannerViewControllerDelegate?) {
        self.titleText = titleText
        self.delegate = delegate
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setContent()
        setStyle()
        qrScanView.delegate = self
        qrScanView.startScanningCheckPermission()
        AnalyticsManager.shared.recordView(.camera)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        qrScanView.prepareForDismissal()
    }

    func setContent() {
        lblTitle.text = titleText ?? "id_scan_qr_code".localized
    }

    func setStyle() {
        lblTitle.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        progressVerticalConstraint.constant = 180
        progressView.isHidden = true
    }

    private func showPermissionAlert() {
        let alert = UIAlertController(
            title: "id_please_enable_camera".localized,
            message: "id_we_use_the_camera_to_scan_qr".localized,
            preferredStyle: .alert
        )
        alert
            .addAction(
                UIAlertAction(title: "id_cancel".localized, style: .cancel)
            )
        alert
            .addAction(
                UIAlertAction(
                    title: "id_settings".localized,
                    style: .default
                ) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        present(alert, animated: true)
    }
    @IBAction func onBack(_ sender: Any) {
        dismiss(animated: true) {
            self.delegate?.didStop()
        }
    }
    @IBAction func onTorch(_ sender: Any) {
        Task { [weak self] in
            guard let self else { return }
            guard await self.qrScanView.isTorchAvailable else { return }
            let active = await self.qrScanView.isTorchActive
            await self.qrScanView.setTorch(on: !active)
            torchButton.imageView?.image = UIImage(systemName: active ? "flashlight.slash" : "flashlight.on.fill")
        }
    }
}

extension QrScannerViewController: QrScannerViewDelegate {
    func didUpdateProgress(_ progress: Float) {
        self.progressView.isHidden = false
        self.progressView.setProgress(progress, animated: true)
    }

    func didFindCode(_ code: ScanResult) {
        qrScanView.prepareForDismissal()
        qrScanView.stopScanning()
        self.dismiss(animated: true) {
            self.delegate?
                .didScan(value: code)
        }
    }

    func didFailWithError(_ error: String) {
        DropAlert().error(message: error)
    }

    func didChangeAuthorization(isAuthorized: Bool) {
        if !isAuthorized {
            showPermissionAlert()
        }
    }
}
