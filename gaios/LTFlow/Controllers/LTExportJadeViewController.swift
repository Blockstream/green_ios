import Foundation
import UIKit
import gdk
import hw
import core

protocol LTExportJadeViewControllerDelegate: AnyObject {
    func didExportedWallet()
}

class LTExportJadeViewController: UIViewController {

    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var qrcodeView: UIView!
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var qrCodeImageView: UIImageView!

    @IBOutlet weak var btnLearnMore: UIButton!
    @IBOutlet weak var btnQREnlarge: UIButton!

    var delegate: LTExportJadeViewControllerDelegate?
    var viewModel: LTExportJadeViewModel!
    private var bcur: BcurEncodedData?

    override func viewDidLoad() {
        super.viewDidLoad()
        setStyle()
        setContent()
        indicator.startAnimating()
        Task { await load() }
    }

    func setContent() {
        title = "Export Lightning Key".localized
        subtitleLabel.text = "Scan QR with Jade".localized
        descriptionLabel.text = "Securely import from your Jade a dedicated key for lightning.".localized
        nextButton.setTitle("id_next".localized, for: .normal)
        let tapQRcodeSmall = UITapGestureRecognizer(target: self, action: #selector(showQRFullScreen))
        qrCodeImageView.addGestureRecognizer(tapQRcodeSmall)
        qrCodeImageView.isUserInteractionEnabled = true
        qrCodeImageView.contentMode = .scaleAspectFit
        btnLearnMore.setTitle("id_learn_more".localized, for: .normal)
        btnQREnlarge.setTitle("Increase QR Size".localized, for: .normal)
    }

    func setStyle() {
        subtitleLabel.setStyle(.title)
        descriptionLabel.setStyle(.txtCard)
        nextButton.setStyle(.primary)
        btnLearnMore.setTitleColor(UIColor.gAccent(), for: .normal)
        btnQREnlarge.setStyle(.qrEnlarge)
    }

    func load() async {
        if let bcurParts = await viewModel.request() {
            await MainActor.run {
                bcur = bcurParts
                qrCodeImageView.bcurQrCode(bcur: bcurParts)
                indicator.stopAnimating()
                indicator.isHidden = true
            }
        }
    }

    func dialogScanViewController() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogScanViewController") as? DialogScanViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            present(vc, animated: false, completion: nil)
        }
    }

    @objc func showQRFullScreen() {
        let stb = UIStoryboard(name: "Utility", bundle: nil)
        if let vc = stb.instantiateViewController(withIdentifier: "MagnifyQRViewController") as? MagnifyQRViewController {
            vc.qrBcur = bcur
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @IBAction func btnLearnMore(_ sender: Any) {
        if let url = URL(string: ExternalUrls.lightningJadeHelp) {
            SafeNavigationManager.shared.navigate( url )
        }
    }

    @IBAction func btnQREnlarge(_ sender: Any) {
        showQRFullScreen()
    }

    @IBAction func tapNextButton(_ sender: Any) {
        dialogScanViewController()
    }
}

extension LTExportJadeViewController: DialogScanViewControllerDelegate {
    func didScan(value: ScanResult, index: Int?) {
        Task { [weak self] in
            await self?.enableLightning(value: value)
        }
    }
    func enableLightning(value: ScanResult) async {
        startLoader(message: String(format: "id_creating_your_s_account".localized, "id_lightning".localized.lowercased()))
        let task = Task.detached { [weak self] in
            guard let credentials = try await self?.viewModel.reply(
                publicKey: value.bcur?.publicΚey ?? "",
                encrypted: value.bcur?.encrypted ?? "") else {
                throw HWError.Abort("id_operation_failure")
            }
            try await self?.viewModel.enableLightning(credentials: credentials)
            return credentials
        }
        switch await task.result {
        case .success:
            self.stopLoader()
            self.navigationController?.popViewController(animated: true)
            self.delegate?.didExportedWallet()
        case .failure(let err):
            self.stopLoader()
            self.showError(err)
        }
    }
    func didStop() {
        //
    }
}
