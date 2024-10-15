import Foundation
import UIKit
import core
import gdk

protocol QRPsbtAquireViewControllerDelegate: AnyObject {
    func didScan(value: ScanResult, index: Int?)
    func didStop()
}

class QRPsbtAquireViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    @IBOutlet weak var btnBack: UIButton!
    @IBOutlet weak var lblNavTitle: UILabel!
    @IBOutlet weak var btnTrouble: UIButton!
    @IBOutlet weak var lblStep: UILabel!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var qrScanView: QRCodeReaderView!
    @IBOutlet weak var progress: UIProgressView!

    weak var delegate: QRPsbtAquireViewControllerDelegate?

    var index: Int?

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        navigationController?.isNavigationBarHidden = true
        qrScanView.delegate = self
        AnalyticsManager.shared.recordView(.camera)
    }

    func setContent() {
        btnBack.setTitle("id_back".localized, for: .normal)
        btnBack.setImage(UIImage(named: "ic_qr_nav_back")?.maskWithColor(color: .white), for: .normal)
        lblNavTitle.text = "id_scan_qr_with_jade".localized
        lblStep.text = "\("id_step".localized) 2".uppercased()
        lblTitle.text = "id_scan_qr_with_jade".localized
        lblHint.text = "id_import_signed_transaction".localized
    }

    func setStyle() {
        progress.isHidden = true

        btnBack.titleLabel?.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        lblNavTitle.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        lblStep.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        lblStep.textColor = UIColor.gGreenMatrix()
        lblTitle.font = UIFont.systemFont(ofSize: 18.0, weight: .bold)
        lblHint.setStyle(.txtCard)
        btnTrouble.setImage(UIImage(named: "ic_help")?.maskWithColor(color: UIColor.gGreenMatrix()), for: .normal)
        qrScanView.layer.masksToBounds = true
        qrScanView.borderWidth = 10.0
        qrScanView.borderColor = UIColor.gGrayCamera()
        qrScanView.cornerRadius = 10.0
    }

    override func viewDidAppear(_ animated: Bool) {

        self.startCapture()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        qrScanView.stopScan()
    }

    func dismiss(_ action: DialogScanAction) {
        switch action {
        case .scan(let result):
            self.delegate?.didScan(value: result, index: self.index)
        case .stop:
            self.delegate?.didStop()
        }
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

    @IBAction func btnBack(_ sender: Any) {
        dismiss(.stop)
    }

    @IBAction func btnTrouble(_ sender: Any) {
        SafeNavigationManager.shared.navigate(ExternalUrls.qrModeScanWithJade)
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
        DispatchQueue.main.async {
            self.dismiss(.scan(result: result))
        }
    }
}
