import Foundation
import core
import UIKit
import gdk
import hw

protocol QRScanOnJadeViewControllerDelegate: AnyObject {
    func signPsbt(_ psbt: String)
}
class QRScanOnJadeViewController: UIViewController {
    
    
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnTrouble: UIButton!
    @IBOutlet weak var lblStep: UILabel!
    @IBOutlet weak var imgStep: UIImageView!
    @IBOutlet weak var progress: UIProgressView!
    @IBOutlet weak var qrcodeImageView: UIImageView!
    @IBOutlet weak var qrcodeBgView: UIView!
    @IBOutlet weak var qrScanView: QRCodeReaderView!
    @IBOutlet weak var btnNext: UIButton!

    var vm: QRScanOnJadeViewModel!
    weak var delegate: QRScanOnJadeViewControllerDelegate?
    private var qrBcur: BcurEncodedData?
    private var credentials: Credentials?
    
    private var bcurDecodedContinuation: CheckedContinuation<BcurDecodedData, Error>?
    private var bcurEncodedContinuation: CheckedContinuation<BcurEncodedData, Error>?

    ///debug only
    var runCount = 0
    var isStarted = false

    override func viewDidLoad() {
        super.viewDidLoad()

        setStyle()
        setContent()
        loadNavigationBtns()
        qrScanView.delegate = self
    }

    func setContent() {
        title = "QR Pin Unlock".localized
        lblTitle.text = vm.title()
        lblHint.text = vm.hint()
        btnNext.setTitle("id_continue".localized, for: .normal)
        btnTrouble.setTitle("id_troubleshoot".localized, for: .normal)
        lblStep.text = vm.stepTitle()
        qrcodeImageView.isHidden = !vm.showQRCode()
        qrcodeBgView.isHidden = !vm.showQRCode()
        btnNext.isHidden = !vm.showQRCode()
    }

    func setStyle() {
        lblTitle.setStyle(.title)
        lblHint.font = UIFont.systemFont(ofSize: 20.0, weight: .regular)
        lblHint.textColor = .gW60()
        btnTrouble.setStyle(.inline)
        lblStep.setStyle(.txtSmaller)
        let tapQRcode = UITapGestureRecognizer(target: self, action: #selector(magnifyQR))
        qrcodeImageView.addGestureRecognizer(tapQRcode)
        qrcodeImageView.isUserInteractionEnabled = true
    }

    func loadNavigationBtns() {
        let settingsBtn = UIButton(type: .system)
        settingsBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        settingsBtn.tintColor = UIColor.gGreenMatrix()
        settingsBtn.setTitle("id_setup_guide".localized, for: .normal)
        settingsBtn.addTarget(self, action: #selector(setupBtnTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: settingsBtn)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        progress.setProgress(0.0, animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refresh()
    }

    @MainActor
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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        qrScanView.stopScan()
    }

    @MainActor
    func refresh() {
        setContent()
    
        switch vm.scope {
        case .oracle:
            startCapture()
        case .handshakeInit:
            startCapture()
        case .handshakeInitReply:
            if let qrBcur = qrBcur {
                qrcodeImageView.bcurQrCode(bcur: qrBcur)
            }
        case .xpub:
            startCapture()
        case .exportPsbt(let psbt):
            Task {
                let qrBcur = try await vm.exportPsbt(psbt: psbt)
                await MainActor.run {
                    self.qrBcur = qrBcur
                    qrcodeImageView.bcurQrCode(bcur: qrBcur)
                }
            }
        case .signPsbt:
            startCapture()
        }
    }

    func onScanCompleted(_ result: ScanResult) {
        switch vm.scope {
        case .oracle:
            vm.oracle = result.result
            vm.scope = .handshakeInit
            refresh()
        case .handshakeInit:
            guard let bcur = result.bcur else {
                startCapture()
                return
            }
            Task {
                do {
                    let bcurHandshake = try await vm.jade.handshakeInit(bcur: bcur)
                    await MainActor.run {
                        vm.scope = .handshakeInitReply
                        qrBcur = bcurHandshake
                        refresh()
                    }
                } catch {
                    startCapture()
                    showError(error)
                }
            }
        case .handshakeInitReply:
            vm.scope = .xpub
            refresh()
        case .xpub:
            guard let bcur = result.bcur else {
                startCapture()
                return
            }
            credentials = Credentials(coreDescriptors: bcur.descriptors)
            let hwFlow = UIStoryboard(name: "QRUnlockFlow", bundle: nil)
            if let vc = hwFlow.instantiateViewController(withIdentifier: "QRUnlockSuccessAlertViewController") as? QRUnlockSuccessAlertViewController {
                vc.delegate = self
                vc.modalPresentationStyle = .overFullScreen
                present(vc, animated: false, completion: nil)
            }
        case .exportPsbt(_):
            vm.scope = .signPsbt
            refresh()
        case .signPsbt:
            guard let bcur = result.bcur else {
                startCapture()
                return
            }
            dismiss(animated: true) {
                self.delegate?.signPsbt(bcur.psbt ?? "")
            }
        }
    }

    @objc func magnifyQR() {
        let stb = UIStoryboard(name: "Utility", bundle: nil)
        if let vc = stb.instantiateViewController(withIdentifier: "MagnifyQRViewController") as? MagnifyQRViewController {
            vc.qrBcur = qrBcur
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    func onScanResult(_ result: ScanResult) {
        print(result)
        DispatchQueue.main.async {
            self.onScanCompleted(result)
        }
    }

    @objc func setupBtnTapped() {
        let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
        if let vc = hwFlow.instantiateViewController(withIdentifier: "SetupJadeViewController") as? SetupJadeViewController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    @IBAction func btnTrouble(_ sender: Any) {

    }
    
    @IBAction func btnNext(_ sender: Any) {
        onScanCompleted(ScanResult.from(result: "", bcur: nil))
    }
}

extension QRScanOnJadeViewController: QRCodeReaderDelegate {
    func onQRCodeReadSuccess(result: ScanResult) {
        qrScanView.stopScan()
        onScanResult(result)
    }

    func userDidGrant(_: Bool) { }
}

extension QRScanOnJadeViewController: QRUnlockSuccessAlertViewControllerDelegate {
    func onTap(_ action: QRUnlockSuccessAlertAction) {
        guard let credentials = credentials else { return }
        switch action {
        case .learnMore:
            break
        case .faceID:
            startLoader(message: "id_logging_in".localized)
            Task {
                do {
                    try await vm.exportXpub(enableBio: true, credentials: credentials)
                    try await vm.login()
                    success(account: vm.account)
                } catch {
                    failure(error, account: vm.account)
                }
            }
        case .later:
            startLoader(message: "id_logging_in".localized)
            Task {
                do {
                    try await vm.exportXpub(enableBio: false, credentials: credentials)
                    try await vm.login()
                    success(account: vm.account)
                } catch {
                    failure(error, account: vm.account)
                }
            }
        }
    }
    
    @MainActor
    func success(account: Account) {
        stopLoader()
        AccountNavigator.goLogged(account: AccountsRepository.shared.current!)
    }
    
    @MainActor
    func failure(_ error: Error, account: Account) {
        var prettyError = "id_login_failed"
        switch error {
        case TwoFactorCallError.failure(let localizedDescription):
            prettyError = localizedDescription
        case LoginError.connectionFailed:
            prettyError = "id_connection_failed"
        case LoginError.failed:
            prettyError = "id_login_failed"
        default:
            break
        }
        stopLoader()
        DropAlert().error(message: NSLocalizedString(prettyError, comment: ""))
        AnalyticsManager.shared.failedWalletLogin(account: account, error: error, prettyError: prettyError)
        WalletsRepository.shared.delete(for: account)
    }
}/*
extension QRScanOnJadeViewController: QRJadeResolver {
    func read() async throws -> gdk.BcurDecodedData {
        return try await withCheckedThrowingContinuation { continuation in
            bcurDecodedContinuation = continuation
        }
    }
    
    func write(bcur: gdk.BcurEncodedData) async throws {
        guard let bcur = bcur as? BcurEncodedData else { return }
        _ = try await withCheckedThrowingContinuation { continuation in
            bcurEncodedContinuation = continuation
        }
    }
}
*/
