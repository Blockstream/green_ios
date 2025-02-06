import Foundation
import core
import UIKit
import gdk
import hw

protocol QRUnlockJadeViewControllerDelegate: AnyObject {
    func login(credentials: Credentials)
    func abort()
    func signerFlow()
}
class QRUnlockJadeViewController: UIViewController {

    @IBOutlet weak var lblNavTitle: UILabel!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnTrouble: UIButton!
    @IBOutlet weak var stepView: UIView!
    @IBOutlet weak var lblStep: UILabel!
    @IBOutlet weak var imgStep: UIImageView!
    @IBOutlet weak var progress: UIProgressView!
    @IBOutlet weak var qrcodeImageView: UIImageView!
    @IBOutlet weak var qrcodeBgView: UIView!
    @IBOutlet weak var qrScanView: QRCodeReaderView!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var btnBack: UIButton!

    @IBOutlet weak var userHelp: UIView!
    @IBOutlet weak var lblUserHelpTitle: UILabel!
    @IBOutlet weak var lblUserHelpHint: UILabel!
    @IBOutlet weak var btnUserHelpScan: UIButton!
    @IBOutlet weak var btnUserHelpLearn: UIButton!
    @IBOutlet weak var jadeImg: UIImageView!

    var vm: QRUnlockJadeViewModel!
    weak var delegate: QRUnlockJadeViewControllerDelegate?
    private var qrBcur: BcurEncodedData?
    private var credentials: Credentials?

    private var bcurDecodedContinuation: CheckedContinuation<BcurDecodedData, Error>?
    private var bcurEncodedContinuation: CheckedContinuation<BcurEncodedData, Error>?

    /// debug only
    var runCount = 0
    var isStarted = false

    var requireSignerFlow = false
    var forceUserhelp = false

    enum Theme {
        case light
        case dark
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.isNavigationBarHidden = true
        theme(.dark)
        setContent()
        setStyle()
        qrScanView.delegate = self
        self.view.alpha = 0.0
        userHelp.isHidden = true
        if forceUserhelp {
            presentUserHelp()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refresh()
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
    }

    func setContent() {
        jadeImg.image = JadeAsset.img(.normalDual, nil)
        btnBack.setTitle("id_back".localized, for: .normal)
        lblNavTitle.text = "id_qr_pin_unlock".localized

        lblTitle.text = vm.title()
        lblHint.text = vm.hint()
        lblStep.text = vm.stepTitle()
        btnNext.setTitle("id_next".localized, for: .normal)
        qrcodeImageView.isHidden = !vm.showQRCode()
        qrcodeBgView.isHidden = !vm.showQRCode()
        btnNext.isHidden = !vm.showQRCode()
        progress.isHidden = true
        lblStep.isHidden = false
        lblUserHelpTitle.text = "Import PubKey".localized
        lblUserHelpHint.text = "id_navigate_on_your_jade_to".localized
        btnUserHelpScan.setTitle("Scan PubKey".localized, for: .normal)
        btnUserHelpLearn.setTitle("id_learn_more".localized, for: .normal)
    }

    func setStyle() {

        progress.isHidden = true
        lblHint.setStyle(.txtCard)
        lblStep.setStyle(.txtSmaller)
        btnBack.titleLabel?.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        lblNavTitle.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        lblTitle.font = UIFont.systemFont(ofSize: 18.0, weight: .bold)
        lblStep.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        lblStep.textColor = UIColor.gGreenMatrix()
        btnNext.setStyle(.primary)
        lblUserHelpTitle.setStyle(.subTitle)
        lblUserHelpHint.setStyle(.txtCard)
        btnUserHelpScan.setStyle(.primary)
        btnUserHelpLearn.setStyle(.inline)
        qrScanView.layer.masksToBounds = true
        qrScanView.borderWidth = 10.0
        qrScanView.borderColor = UIColor.gGrayCamera()
        qrScanView.cornerRadius = 10.0
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        progress.setProgress(0.0, animated: false)
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
            theme(.dark)
            startCapture()
        case .handshakeInit:
            theme(.dark)
            startCapture()
        case .handshakeInitReply:
            theme(.light)
            if let qrBcur = qrBcur {
                qrcodeImageView.bcurQrCode(bcur: qrBcur)
            }
        case .xpub:
            lblNavTitle.isHidden = true
            stepView.isHidden = true
            theme(.dark)
            startCapture()
        }
    }

    func presentUserHelp() {
        view.bringSubviewToFront(userHelp)
        userHelp.alpha = 0.0
        userHelp.isHidden = false
        lblNavTitle.isHidden = true
        btnTrouble.isHidden = true
        UIView.animate(withDuration: 0.3) {
            self.userHelp.alpha = 1.0
            self.theme(.dark)
        }
    }

    func dismissUserHelp() {
        lblNavTitle.isHidden = false
        btnTrouble.isHidden = false
        UIView.animate(withDuration: 0.3, delay: 0.3) {
            self.userHelp.alpha = 0.0
        } completion: { _ in
            self.userHelp.isHidden = true
        }
    }

    func theme(_ theme: Theme) {
        switch theme {
        case .light:
            imgStep.image = vm.icon()
            lblNavTitle.textColor = .black
            lblTitle.textColor = .black
            lblHint.textColor = .black
            btnBack.setImage(UIImage(named: "ic_qr_nav_back")?.maskWithColor(color: .black), for: .normal)
            btnBack.setTitleColor(.black, for: .normal)
            view.backgroundColor = .white
            btnTrouble.setImage(UIImage(named: "ic_help")?.maskWithColor(color: .black), for: .normal)
        case .dark:
            imgStep.image = vm.icon()
            lblNavTitle.textColor = .white
            lblTitle.textColor = .white
            lblHint.textColor = UIColor.gW40()
            btnBack.setImage(UIImage(named: "ic_qr_nav_back")?.maskWithColor(color: .white), for: .normal)
            btnBack.setTitleColor(.white, for: .normal)
            btnTrouble.setImage(UIImage(named: "ic_help")?.maskWithColor(color: .white), for: .normal)
            view.backgroundColor = UIColor.gBlackBg()
        }
    }

    func onScanOracle(_ result: ScanResult) async {
        guard let bcur = result.bcur else {
            vm.oracle = result.result
            vm.scope = .handshakeInit
            refresh()
            return
        }
        await onScanHandshakeInit(result)
    }

    func onScanHandshakeInit(_ result: ScanResult) async {
        guard let bcur = result.bcur else {
            startCapture()
            return
        }
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

    func onScanCompleted(_ result: ScanResult) {
        switch vm.scope {
        case .oracle:
            Task {
                await onScanOracle(result)
            }
        case .handshakeInit:
            Task {
                await onScanHandshakeInit(result)
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

    @IBAction func btnBack(_ sender: Any) {
        dismiss(animated: true) {
            self.delegate?.abort()
        }
    }

    @IBAction func btnTrouble(_ sender: Any) {
        SafeNavigationManager.shared.navigate(ExternalUrls.scanQRFixIssues)
    }

    @IBAction func btnNext(_ sender: Any) {

        if requireSignerFlow == true {
            self.delegate?.signerFlow()
        } else {
            presentUserHelp()
        }
    }

    @IBAction func btnUserHelpScan(_ sender: Any) {
        dismissUserHelp()
        onScanCompleted(ScanResult.from(result: "", bcur: nil))
    }

    @IBAction func btnUserHelpLearn(_ sender: Any) {
        SafeNavigationManager.shared.navigate(ExternalUrls.qrModeAirGapSupport)
    }
}

extension QRUnlockJadeViewController: QRCodeReaderDelegate {
    func onBcurProgress(_ info: gdk.ResolveCodeAuthData) {
        progress.progress = Float((info.estimatedProgress ?? 0)) / 100
        progress.isHidden = false
    }

    func onQRCodeReadSuccess(result: ScanResult) {
        qrScanView.stopScan()
        onScanResult(result)
    }

    func userDidGrant(_: Bool) { }
}

extension QRUnlockJadeViewController: QRUnlockSuccessAlertViewControllerDelegate {
    func onTap(_ action: QRUnlockSuccessAlertAction) {
        guard let credentials = credentials else { return }
        switch action {
        case .bio:
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
        }
    }

    @MainActor
    func success(account: Account) {
        stopLoader()
        dismiss(animated: true) {
            if let credentials = self.credentials {
                self.delegate?.login(credentials: credentials)
            }
        }
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
        DropAlert().error(message: prettyError.localized)
        AnalyticsManager.shared.failedWalletLogin(account: account, error: error, prettyError: prettyError)
        WalletsRepository.shared.delete(for: account)
    }
}
