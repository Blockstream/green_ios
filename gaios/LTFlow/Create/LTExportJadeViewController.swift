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
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var qrCodeView: QRCodeView!
    @IBOutlet weak var qrCodeFrame: UIView!
    @IBOutlet weak var btnQREnlarge: UIButton!

    var delegate: LTExportJadeViewControllerDelegate?
    var viewModel: LTExportJadeViewModel!
    private var bcur: BcurEncodedData?

    override func viewDidLoad() {
        super.viewDidLoad()
        setContent()
        setStyle()
        setupAlertCard()
        Task { await load() }
    }

    func setContent() {
        subtitleLabel.text = "Enable Lightning".localized
        descriptionLabel.text = "Unlock your Jade and scan this QR. Jade keeps your private keys secure.".localized
        nextButton.setTitle("id_next".localized, for: .normal)
        let tapQRcodeSmall = UITapGestureRecognizer(target: self, action: #selector(showQRFullScreen))
        qrCodeView.addGestureRecognizer(tapQRcodeSmall)
        qrCodeView.isUserInteractionEnabled = true
        let image = UIImage(named: "ic_magnify_qr")?.maskWithColor(color: UIColor.gAccent())
        btnQREnlarge.setImage(image, for: .normal)
        btnQREnlarge.setTitle("id_increase_qr_size".localized, for: .normal)
    }

    func setStyle() {
        subtitleLabel.setStyle(.titleDialog)
        subtitleLabel.textAlignment = .center
        descriptionLabel.setStyle(.txtCard)
        descriptionLabel.textAlignment = .center
        qrCodeFrame.backgroundColor = .clear
        qrCodeFrame.borderWidth = 5.0
        qrCodeFrame.borderColor = UIColor.gAccent()
        qrCodeFrame.cornerRadius = 20.0
        btnQREnlarge.setStyle(.outlined)
        btnQREnlarge.tintColor = UIColor.gAccent()
        nextButton.setStyle(.primary)
    }
    
    func setupAlertCard() {
        let nib = UINib(nibName: "AlertCardCell", bundle: nil)
        guard let cell = nib.instantiate(withOwner: nil, options: nil).first as? AlertCardCell else { return }
        cell.configure(AlertCardCellModel(type: .lightningOnJade), onLeft: nil, onRight: nil, onDismiss: nil)
        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(cell)
        
        NSLayoutConstraint.activate([
            cell.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -5),
            cell.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 5),
            cell.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -12),
            cell.contentView.topAnchor.constraint(equalTo: cell.topAnchor),
            cell.contentView.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
            cell.contentView.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            cell.contentView.trailingAnchor.constraint(equalTo: cell.trailingAnchor)
        ])
    }

    @MainActor
    func load() async {
        if let bcurParts = try? await viewModel.request() {
            self.bcur = bcurParts
            qrCodeView.configure(frames: bcurParts.parts)
        }
    }

    func presentQrScannerViewController() {
        let storyboard = UIStoryboard(name: "Scanner", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "QrScannerViewController") { coder in
            QrScannerViewController(coder: coder, titleText: nil, delegate: self)
        }
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: false, completion: nil)
    }

    @objc func showQRFullScreen() {
        let stb = UIStoryboard(name: "Qrcode", bundle: nil)
        if let vc = stb.instantiateViewController(withIdentifier: "MagnifyQRViewController") as? MagnifyQRViewController {
            vc.qrBcur = bcur
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @IBAction func btnQREnlarge(_ sender: Any) {
        showQRFullScreen()
    }

    @IBAction func tapNextButton(_ sender: Any) {
        presentQrScannerViewController()
    }
}

extension LTExportJadeViewController: QrScannerViewControllerDelegate {
    func didScan(value: ScanResult) {
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
