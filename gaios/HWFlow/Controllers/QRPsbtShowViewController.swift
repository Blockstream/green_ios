import Foundation
import UIKit
import gdk
import greenaddress
import core
import UniformTypeIdentifiers
import green.wally

class QRPsbtShowViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var qr: UIImageView!
    @IBOutlet weak var lblStep: UILabel!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!

    @IBOutlet weak var imgStep: UIImageView!
    @IBOutlet weak var btnVerify: UIButton!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var btnExport: UIButton!

    var qrTxt: String?
    var qrBcur: BcurEncodedData?
    var unsignedPsbt: String?

    var confirmModel: SendHWConfirmViewModel?
    var followsQRUnlock = false
    var didPickDocumentCallback: ((URL) -> Void) = {_ in }

    weak var delegate: QRPsbtAquireViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        updateNavigationItem()
        setStyle()
        setContent()
    }

    func setContent() {
        title = "id_scan_qr_with_jade".localized
        lblStep.text = "\("id_step".localized) 1".uppercased()
        lblTitle.text = "id_scan_qr_with_jade".localized
        lblHint.text = "id_validate_the_transaction".localized
        btnVerify.setTitle("id_check_transaction_details".localized, for: .normal)
        btnNext.setTitle("id_next".localized, for: .normal)
        btnExport.setTitle("Export Transaction".localized, for: .normal)
    }

    func setStyle() {
        lblStep.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        lblStep.textColor = UIColor.gAccent()
        lblTitle.font = UIFont.systemFont(ofSize: 18.0, weight: .bold)
        lblHint.font = UIFont.systemFont(ofSize: 12.0, weight: .regular)
        lblHint.textColor = .black
        btnVerify.setStyle(.outlinedBlack)
        btnExport.setStyle(.outlinedBlack)
        btnNext.setStyle(.primary)
        imgStep.image = UIImage(named: "ic_qr_scan_shield")?.maskWithColor(color: UIColor.gAccent())
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presentQRUnlockSignDialogViewController()
        if let bcur = qrBcur {
            qr.bcurQrCode(bcur: bcur)
        } else if let text = qrTxt {
            qr.qrCode(text: text)
        } else {
            qr.image = UIImage()
        }
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

    @IBAction func btnVerify(_ sender: Any) {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendHWConfirmViewController") as? SendHWConfirmViewController, let model = confirmModel {
            vc.viewModel = model
            vc.isDismissible = true
            vc.isQRMode = true
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }
    func psbtNameFile() -> String {
        let dateFormatter = DateFormatter()
        let date = Date()
        dateFormatter.dateFormat = "yyyy_MM_dd_HHmm"
        let dateString = dateFormatter.string(from: date)
        return "tx_\(dateString).psbt"
    }

    func exportPsbtToFile(psbt: String) async throws {
        let fileUrl = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let destinationUrl = fileUrl.appendingPathComponent(psbtNameFile())
        if FileManager().fileExists(atPath: destinationUrl.path) {
            try FileManager().removeItem(at: destinationUrl)
        }
        try psbt.write(to: destinationUrl, atomically: true, encoding: .utf8)
        let activityViewController = UIActivityViewController(activityItems: [destinationUrl], applicationActivities: nil)
        present(activityViewController, animated: true, completion: nil)
    }

    func export() async {
        let task = Task { [weak self] in
            // Convert it to v0 for better compatibility
            guard var psbt = self?.unsignedPsbt else {
                throw GaError.GenericError("Empty Psbt")
            }
            let wallyPsbt = try Wally.psbtFromBase64(psbt)
            let version = try Wally.psbtGetVersion(wallyPsbt)
            if version == UInt32(WALLY_PSBT_VERSION_2) {
                try Wally.psbtSetVersion(wallyPsbt, version: UInt32(WALLY_PSBT_VERSION_0))
            }
            psbt = try Wally.psbtToBase64(wallyPsbt)
            try await self?.exportPsbtToFile(psbt: psbt)
        }
        switch await task.result {
        case .success:
            break // nothing
        case .failure(let err):
            logger.error("Error: \(err.description().localized)")
            showError(err.description().localized)
        }
    }

    @IBAction func btnExport(_ sender: Any) {
        Task {
            await export()
        }
    }
    @IBAction func btnNext(_ sender: Any) {
        pushQRPsbtAquireViewController()
    }

    @MainActor
    func pushQRPsbtAquireViewController() {
        let storyboard = UIStoryboard(name: "QRUnlockFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "QRPsbtAquireViewController") as? QRPsbtAquireViewController {
            vc.delegate = delegate
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    @MainActor
    func presentQRUnlockSignDialogViewController() {
        let stb = UIStoryboard(name: "QRUnlockFlow", bundle: nil)
        if let vc = stb.instantiateViewController(withIdentifier: "QRUnlockSignDialogViewController") as? QRUnlockSignDialogViewController {
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: true)
        }
    }
}

extension QRPsbtShowViewController: QRUnlockSignDialogViewControllerDelegate {
    func onTap(_ action: QRUnlockSignDialogAction) {
        switch action {
        case .cancel:
            break
        case .connect:
            break
        case .unlocked:
            break
        case .unlock:
            presentQRPinUnlockFlow()
        }
    }

    func presentQRPinUnlockFlow() {
        let storyboard = UIStoryboard(name: "QRUnlockFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "QRUnlockJadeViewController") as? QRUnlockJadeViewController {
            vc.vm = QRUnlockJadeViewModel(scope: .oracle, testnet: WalletManager.current?.prominentNetwork.testnet ?? false, askXpub: false)
            vc.delegate = self
            present(vc, animated: true)
        }
    }
}
extension QRPsbtShowViewController: QRUnlockJadeViewControllerDelegate {
    func unlock() {
        // nothing
    }

    func login(credentials: gdk.Credentials, wallet: core.WalletManager) {
        print("login")
    }
    func abort() {
        print("abort")
    }
}
