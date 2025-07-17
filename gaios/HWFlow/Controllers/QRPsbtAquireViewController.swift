import Foundation
import UIKit
import core
import gdk
import greenaddress

protocol QRPsbtAquireViewControllerDelegate: AnyObject {
    func didCancel()
    func didSign(psbt: String)
}

class QRPsbtAquireViewController: UIViewController {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblStep: UILabel!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var qrScanView: QRCodeReaderView!
    @IBOutlet weak var progress: UIProgressView!
    @IBOutlet weak var imgStep: UIImageView!
    @IBOutlet weak var btnImport: UIButton!
    weak var delegate: QRPsbtAquireViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        updateNavigationItem()
        setContent()
        setStyle()
        qrScanView.delegate = self
        AnalyticsManager.shared.recordView(.camera)
        view.backgroundColor = UIColor.gBlackBg()
//        view.alpha = 0.0
    }

    func setContent() {
        title = "id_scan_qr_with_jade".localized
        lblStep.text = "\("id_step".localized) 2".uppercased()
        lblTitle.text = "id_scan_qr_on_jade".localized
        lblHint.text = "id_import_signed_transaction".localized
        btnImport.setTitle("Import from file", for: .normal)
    }

    func setStyle() {
        progress.isHidden = true
        lblStep.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        lblStep.textColor = UIColor.gAccent()
        lblTitle.font = UIFont.systemFont(ofSize: 18.0, weight: .bold)
        lblHint.setStyle(.txtCard)
        qrScanView.layer.masksToBounds = true
        qrScanView.borderWidth = 10.0
        qrScanView.borderColor = UIColor.gGrayCamera()
        qrScanView.cornerRadius = 10.0
        imgStep.image = UIImage(named: "ic_qr_scan_square")?.maskWithColor(color: UIColor.gAccent())
        btnImport.setStyle(.outlinedWhite)
    }

    override func viewDidAppear(_ animated: Bool) {
//        UIView.animate(withDuration: 0.3) {
//            self.view.alpha = 1.0
//            self.view.layoutIfNeeded()
//        }
        Task.detached(priority: .medium) { [weak self] in
            await self?.startCapture()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        qrScanView.stopScan()
    }

    func dismiss(animated: Bool) {
        navigationController?.popToViewController(ofClass: SendTxConfirmViewController.self)
    }

    private func startCapture() {
        if qrScanView.isSessionNotDetermined() {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                self.startCapture()
            }
            return
        }
        if !qrScanView.isSessionAuthorized() {
            return
        }
        qrScanView.startScan()
    }

    func updateNavigationItem() {
        let helpBtn = UIButton(type: .system)
        helpBtn.setStyle(.inline)
        helpBtn.setImage(UIImage(named: "ic_help"), for: .normal)
        helpBtn.addTarget(self, action: #selector(helpBtnTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItems = [UIBarButtonItem(customView: helpBtn)]
    }

    @objc func helpBtnTapped(_ sender: Any) {
        SafeNavigationManager.shared.navigate(ExternalUrls.qrModeScanWithJade)
    }

    @IBAction func importBtnTapped(_ sender: Any) {
        let documentPickerViewController =  UIDocumentPickerViewController(forOpeningContentTypes: [.text, .data, .item], asCopy: false)
        documentPickerViewController.delegate = self
        present(documentPickerViewController, animated: true)
    }

    func validatePsbt(psbt: Data) throws -> String {
        if Wally.psbtIsBytes(psbt.bytes) {
            let wallyPsbt = try Wally.psbtFromBytes(psbt.bytes)
            return try Wally.psbtToBase64(wallyPsbt)
        } else if let txt = String(data: psbt, encoding: .utf8) {
            let txt = txt.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
            if Wally.psbtIsBase64(txt) {
                return txt
            }
        }
        throw GaError.GenericError("Not a valid PSBT")
    }
}
extension QRPsbtAquireViewController: UIDocumentPickerDelegate {
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        delegate?.didCancel()
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        do {
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            let data = try Data(contentsOf: url)
            let psbt = try validatePsbt(psbt: data)
            DispatchQueue.main.async {
                self.delegate?.didSign(psbt: psbt)
                self.dismiss(animated: true)
            }
        } catch {
            showError(error.description().localized)
        }
    }
}

extension QRPsbtAquireViewController: QRCodeReaderDelegate {
    func onBcurProgress(_ info: gdk.ResolveCodeAuthData) {
        progress.progress = Float((info.estimatedProgress ?? 0)) / 100
        progress.isHidden = false
    }

    func userDidGrant(_: Bool) { }

    func onQRCodeReadSuccess(result: ScanResult) {
        qrScanView.stopScan()
        do {
            guard let psbt = result.bcur?.psbt,
                  Wally.psbtIsBase64(psbt)
            else {
                throw GaError.GenericError("Not a valid PSBT")
            }
            DispatchQueue.main.async {
                self.delegate?.didSign(psbt: psbt)
                self.dismiss(animated: true)
            }
        } catch {
            showError(error.description().localized)
        }
    }
}
