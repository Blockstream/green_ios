import Foundation
import UIKit
import core

protocol DialogScanViewControllerDelegate: AnyObject {
    func didScan(value: ScanResult, index: Int?)
    func didStop()
}

enum DialogScanAction {
    case scan(result: ScanResult)
    case stop
}

class DialogScanViewController: KeyboardViewController {

    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var qrScanView: QRCodeReaderView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var btnClose: UIButton!

    var index: Int?
    var delegate: DialogScanViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()

        view.alpha = 0.0

        qrScanView.delegate = self
        AnalyticsManager.shared.recordView(.camera)
    }

    deinit {
        print("deinit")
    }

    func setContent() {
        lblTitle.text = NSLocalizedString("id_scan_qr_code", comment: "")
    }

    func setStyle() {
        lblTitle.font = UIFont.systemFont(ofSize: 16.0, weight: .regular)
        btnClose.setImage((UIImage(named: "cancel")!.maskWithColor(color: .white)), for: .normal)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
            self.startCapture()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        qrScanView.stopScan()
    }

    func dismiss(_ action: DialogScanAction) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
            switch action {
            case .scan(let result):
                self.delegate?.didScan(value: result, index: self.index)
            case .stop:
                self.delegate?.didStop()
            }
        })
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

    static var vc: DialogScanViewController? {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogScanViewController") as? DialogScanViewController {
            vc.modalPresentationStyle = .overFullScreen
            return vc
        }
        return nil
    }

    @IBAction func btnClose(_ sender: Any) {
        dismiss(.stop)
    }
}

extension DialogScanViewController: QRCodeReaderDelegate {

    func userDidGrant(_: Bool) { }

    func onQRCodeReadSuccess(result: ScanResult) {
        qrScanView.stopScan()
        DispatchQueue.main.async {
            self.dismiss(.scan(result: result))
        }
    }
}
