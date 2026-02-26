import Foundation
import UIKit
import gdk
import hw
import core

protocol JadeBoltzExportViewControllerDelegate: AnyObject {
    func onExportSucceed()
}
class JadeBoltzExportViewController: UIViewController {

    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var qrcodeView: UIView!
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var btnQREnlarge: UIButton!
    weak var delegate: JadeBoltzExportViewControllerDelegate?
    let viewModel: JadeBoltzExportViewModel

    init?(coder: NSCoder, viewModel: JadeBoltzExportViewModel) {
        self.viewModel = viewModel
        super.init(coder: coder)
    }
    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setStyle()
        setContent()
        viewModel.onReload = { Task { await self.reload() }}
        viewModel.onError = { self.showError($0.description().localized) }
        Task.detached { [weak viewModel] in await viewModel?.performRequest() }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Connect jade if there is no active connection
        if viewModel.mainAccount.isJade {
            if !BleHwManager.shared.isConnected() || !BleHwManager.shared.isLogged() {
                let vc = hWDialogConnectViewController()
                present(vc, animated: true)
            }
        }
    }

    func setContent() {
        title = ""
        subtitleLabel.text = "Enable swaps".localized
        descriptionLabel.text = "Unlock Jade and scan this QR code to enable swaps. Jade keeps your private keys secure.".localized
        nextButton.setTitle("id_next".localized, for: .normal)
        let tapQRcodeSmall = UITapGestureRecognizer(target: self, action: #selector(showQRFullScreen))
        qrCodeImageView.addGestureRecognizer(tapQRcodeSmall)
        qrCodeImageView.isUserInteractionEnabled = true
        qrCodeImageView.contentMode = .scaleAspectFit
        btnQREnlarge.setTitle("id_increase_qr_size".localized, for: .normal)
    }

    func setStyle() {
        subtitleLabel.setStyle(.title)
        descriptionLabel.setStyle(.txtCard)
        nextButton.setStyle(.primary)
        btnQREnlarge.setStyle(.qrEnlarge)
    }

    func hWDialogConnectViewController() -> HWDialogConnectViewController {
        let storyboard = UIStoryboard(name: "HWDialogs", bundle: nil)
        // swiftlint:disable:next force_cast
        let vc = storyboard.instantiateViewController(withIdentifier: "HWDialogConnectViewController") as! HWDialogConnectViewController
        vc.delegate = self
        vc.modalPresentationStyle = .overFullScreen
        return vc
    }

    @MainActor
    func reload() async {
        if let bcur = viewModel.bcurParts {
            qrCodeImageView.bcurQrCode(bcur: bcur)
            indicator.stopAnimating()
            indicator.isHidden = true
        } else {
            indicator.startAnimating()
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
            vc.qrBcur = viewModel.bcurParts
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    func dialogSwapEnabledViewController() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogSwapJadeEnabledViewController") as? DialogSwapJadeEnabledViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            present(vc, animated: false, completion: nil)
        }
    }

    @IBAction func btnQREnlarge(_ sender: Any) {
        showQRFullScreen()
    }

    @IBAction func tapNextButton(_ sender: Any) {
        dialogScanViewController()
    }
}

extension JadeBoltzExportViewController: DialogScanViewControllerDelegate {
    func didScan(value: ScanResult, index: Int?) {
        Task { [weak self] in
            await self?.storeKey(value: value)
        }
    }
    func storeKey(value: ScanResult) async {
        startLoader()
        let task = Task.detached { [weak self] in
            await self?.viewModel.performReply(
                publicKey: value.bcur?.publicΚey ?? "",
                encrypted: value.bcur?.encrypted ?? "")
            try await self?.viewModel.performStoreKey()
            try await self?.viewModel.loginBoltz()
        }
        switch await task.result {
        case .success:
            self.stopLoader()
            self.dialogSwapEnabledViewController()
        case .failure(let err):
            self.stopLoader()
            self.showError(err)
        }
    }
    func didStop() {
        //
    }
}
extension JadeBoltzExportViewController: DialogSwapJadeEnabledViewControllerDelegate {
    func onSwapEnabledDone() {
        delegate?.onExportSucceed()
    }
}

extension JadeBoltzExportViewController: HWDialogConnectViewControllerDelegate {
    func connected() {
    }

    func logged() {
    }

    func cancel() {
        showError(HWError.Abort("id_cancel"))
    }

    func failure(err: Error) {
        showError(err)
    }
}
