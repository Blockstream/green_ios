import Foundation
import UIKit
import gdk
import hw

protocol LTExportJadeViewControllerDelegate: AnyObject {
    func didExportedWallet(credentials: Credentials, wallet: WalletItem)
}

class LTExportJadeViewModel {
    private var wm: WalletManager? { WalletManager.current }
    private var privateKey: Data?
    
    func request() async -> BcurEncodedData? {
        guard let session = wm?.prominentSession else { return nil }
        let (privateKey, bcurParts) = await session.jadeBip8539Request()
        self.privateKey = privateKey
        return bcurParts
    }
    
    func reply(publicKey: String, encrypted: String) async throws -> Credentials {
        guard let session = wm?.prominentSession else {
            throw HWError.Abort("Invalid session")
        }
        guard let privateKey = privateKey else {
            throw HWError.Abort("Invalid private key")
        }
        let lightningMnemonic = await session.jadeBip8539Reply(
            privateKey: privateKey,
            publicKey: publicKey.hexToData(),
            encrypted: encrypted.hexToData())
        guard let lightningMnemonic = lightningMnemonic else {
            throw HWError.Abort("Invalid key derivation")
        }
        let credentials = Credentials(mnemonic: lightningMnemonic)
        try await wm?.lightningSession?.connect()
        try await wm?.lightningSession?.register(credentials: credentials)
        try await WalletManager.current?.subaccounts()
        return credentials
    }

    func subaccount() async throws -> WalletItem? {
        try await wm?.lightningSubaccount
    }
}

class LTExportJadeViewController: UIViewController {
    
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var qrcodeView: UIView!
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var qrCodeBigImageView: UIImageView!
    @IBOutlet weak var overlayView: UIView!
    
    var delegate: LTExportJadeViewControllerDelegate?
    private var isActive = false
    private var currentIndex = 0
    private let viewModel = LTExportJadeViewModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setStyle()
        setContent()
        Task { await load() }
    }

    func setContent() {
        title = "Export Lightning Key to Green".localized
        subtitleLabel.text = "Scan QR with Jade".localized
        descriptionLabel.text = "Jade will securely create and transfer a new key to your Green app. Jade will not be needed to authorize lightning transactions, because Green will use this new key for your lightning transactions.\n\nDon't worry about any new backups, your existing recovery phrase backup will be sufficient to restore both your funds onchain and on lightning."
        nextButton.setTitle("id_next".localized, for: .normal)
        let tapQRcodeSmall = UITapGestureRecognizer(target: self, action: #selector(showQRFullScreen))
        qrCodeImageView.addGestureRecognizer(tapQRcodeSmall)
        qrCodeImageView.isUserInteractionEnabled = true
        qrCodeImageView.contentMode = .scaleAspectFit
        qrCodeBigImageView.contentMode = .scaleAspectFit
        let tapQRcodeBig = UITapGestureRecognizer(target: self, action: #selector(hideFullScreen))
        overlayView.addGestureRecognizer(tapQRcodeBig)
        overlayView.isUserInteractionEnabled = true
    }

    func setStyle() {
        subtitleLabel.setStyle(.txtBigger)
        descriptionLabel.setStyle(.txt)
        nextButton.setStyle(.primary)
        overlayView.isHidden = true
        overlayView.backgroundColor = .black.withAlphaComponent(0.6)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        isActive = true
        indicator.startAnimating()
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        isActive = false
    }

    func load() async {
        let bcurParts = await viewModel.request()
        currentIndex = 0
        while isActive {
            if currentIndex >= bcurParts?.parts.count ?? 0 {
                currentIndex = 0
            }
            if let part = bcurParts?.parts[currentIndex] {
                await MainActor.run {
                    qrCodeImageView.image = QRImageGenerator.imageForTextWhite(text: part, frame: qrCodeImageView.frame)
                    qrCodeBigImageView.image = QRImageGenerator.imageForTextWhite(text: part, frame: qrCodeBigImageView.frame)
                    indicator.stopAnimating()
                    indicator.isHidden = true
                }
            }
            currentIndex += 1
            try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
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

    @objc func showQRFullScreen()
    {
        overlayView.isHidden = false
    }
    @objc func hideFullScreen()
    {
        overlayView.isHidden = true
    }

    @IBAction func tapNextButton(_ sender: Any) {
        dialogScanViewController()
    }
}


extension LTExportJadeViewController: DialogScanViewControllerDelegate {
    func didScan(value: ScanResult, index: Int?) {
        startLoader(message: "")
        Task {
            do {
                let credentials = try await viewModel.reply(
                    publicKey: value.bcur?.publicΚey ?? "",
                    encrypted: value.bcur?.encrypted ?? "")
                if let subaccount = try await viewModel.subaccount() {
                    await MainActor.run {
                        self.stopLoader()
                        self.navigationController?.popViewController(animated: true)
                        self.delegate?.didExportedWallet(credentials: credentials, wallet: subaccount)
                    }
                }
            } catch {
                self.stopLoader()
                self.showError(error)
            }
        }
    }
    func didStop() {
        //
    }
}
