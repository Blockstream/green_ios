import Foundation
import UIKit
import gdk

protocol QRPsbtShowViewControllerDelegate: AnyObject {
    func close()
    func next()
}

class QRPsbtShowViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var qr: UIImageView!
    @IBOutlet weak var btnBack: UIButton!
    @IBOutlet weak var lblNavTitle: UILabel!
    @IBOutlet weak var btnTrouble: UIButton!
    @IBOutlet weak var lblStep: UILabel!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!

    @IBOutlet weak var btnVerify: UIButton!
    @IBOutlet weak var btnNext: UIButton!

    var qrTxt: String?
    var qrBcur: BcurEncodedData?

    var confirmModel: SendHWConfirmViewModel?
    var followsQRUnlock = false

    weak var delegate: QRPsbtShowViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.isNavigationBarHidden = true
        setStyle()
        setContent()
        if !followsQRUnlock {
            self.view.alpha = 0.0
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !followsQRUnlock {
            UIView.animate(withDuration: 0.3) {
                self.view.alpha = 1.0
            }
        }
    }

    func setContent() {
        btnBack.setTitle("id_back".localized, for: .normal)
        lblNavTitle.text = "Scan with Jade"
        lblStep.text = "\("id_step".localized) 1".uppercased()
        lblTitle.text = "id_scan_qr_with_jade".localized
        lblHint.text = "Start Scan QR on Jade and validate the transaction details on Jade".localized
        btnVerify.setTitle("Check Transaction Details", for: .normal)
        btnNext.setTitle("Import Signed Transaction", for: .normal)
        btnTrouble.setTitle("id_troubleshoot".localized, for: .normal)
    }

    func setStyle() {
        btnBack.titleLabel?.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        lblNavTitle.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        lblNavTitle.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        btnTrouble.titleLabel?.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        lblStep.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        lblStep.textColor = UIColor.gGreenMatrix()
        lblTitle.font = UIFont.systemFont(ofSize: 18.0, weight: .bold)
        lblHint.font = UIFont.systemFont(ofSize: 12.0, weight: .regular)
        lblHint.textColor = .black
        btnVerify.setStyle(.outlinedBlack)
        btnNext.setStyle(.primary)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let bcur = qrBcur {
            qr.bcurQrCode(bcur: bcur)
        } else if let text = qrTxt {
            qr.qrCode(text: text)
        } else {
            qr.image = UIImage()
        }
    }

    @objc func onTap(sender: UITapGestureRecognizer) {
        dismiss() { [weak self] in
            self?.delegate?.close()
        }
    }

    func dismiss(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: {
                completion()
            })
        })
    }

    @IBAction func btnBack(_ sender: Any) {
        dismiss() { [weak self] in
            self?.delegate?.close()
        }
    }

    @IBAction func btnTrouble(_ sender: Any) {
        SafeNavigationManager.shared.navigate(ExternalUrls.qrModeScanWithJade)
    }

    @IBAction func btnVerify(_ sender: Any) {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendHWConfirmViewController") as? SendHWConfirmViewController, let model = confirmModel {
            vc.viewModel = model
            vc.isDismissible = true
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @IBAction func btnNext(_ sender: Any) {
        delegate?.next()
    }
}
