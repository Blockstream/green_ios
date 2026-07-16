import Foundation
import core
import UIKit

import hw

protocol QRUnlockJadeViewControllerDelegate: AnyObject {
    func login(credentials: Credentials, wm: WalletManager, wallet: Wallet)
    func abort()
}
class QRUnlockJadeViewController: UIViewController {
    
    @IBOutlet weak var navBar: UINavigationBar!
    @IBOutlet weak var navItem: UINavigationItem!
    @IBOutlet weak var btnBack: UIBarButtonItem!
    @IBOutlet weak var btnTrouble: UIBarButtonItem!

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var stepView: UIView!
    @IBOutlet weak var lblStep: UILabel!
    @IBOutlet weak var imgStep: UIImageView!
    @IBOutlet weak var qrCodeView: QRCodeView!
    @IBOutlet weak var qrScanView: QrScannerView!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var progressView: SmoothProgressView!

    var vm: QRUnlockJadeViewModel!
    weak var delegate: QRUnlockJadeViewControllerDelegate?
    private var qrBcur: BcurEncodedData?
    private var credentials: Credentials?

    private var bcurDecodedContinuation: CheckedContinuation<BcurDecodedData, Error>?
    private var bcurEncodedContinuation: CheckedContinuation<BcurEncodedData, Error>?

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
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refresh()
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
    }

    func setContent() {
        setupNavigationBar()

        lblTitle.text = vm.title()
        lblHint.text = vm.hint()
        lblStep.text = vm.stepTitle()
        btnNext.setTitle("id_next".localized, for: .normal)
        qrCodeView.isHidden = !vm.showQRCode()
        btnNext.isHidden = !vm.showQRCode()
        progressView.isHidden = true
        lblStep.isHidden = false
    }

    private func setupNavigationBar() {
        navBar.layoutMargins = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        navBar.preservesSuperviewLayoutMargins = false
        
        var backConfig = UIButton.Configuration.plain()
        backConfig.image = UIImage(systemName: "chevron.backward", withConfiguration: UIImage.SymbolConfiguration(weight: .semibold))
        backConfig.imagePadding = 6
        backConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: -8, bottom: 0, trailing: 0)
        var attrTitle = AttributedString("id_back".localized)
        attrTitle.font = UIFont.systemFont(ofSize: 17)
        backConfig.attributedTitle = attrTitle
        
        let customBackBtn = UIButton(configuration: backConfig)
        customBackBtn.addTarget(self, action: #selector(btnBackTapped(_:)), for: .touchUpInside)
        btnBack.customView = customBackBtn
        
        btnTrouble.title = ""
        btnTrouble.image = UIImage(named: "ic_help")
        btnTrouble.target = self
        btnTrouble.action = #selector(btnTroubleTapped(_:))
        
        navItem.title = "id_qr_pin_unlock".localized
    }

    func setStyle() {
        progressView.isHidden = true
        progressView.progressColor = UIColor.gAccent()
        lblStep.setStyle(.txtCard)
        lblTitle.setStyle(.titleDialog)
        lblHint.setStyle(.txtCard)
        lblTitle.font = UIFont.systemFont(ofSize: 18.0, weight: .bold)
        lblStep.setStyle(.txtCard)
        btnNext.setStyle(.primary)
        qrScanView.layer.masksToBounds = true
        qrScanView.cornerRadius = 10.0
    }

    @MainActor
    private func startCapture() {
        progressView.setProgress(0.0)
        qrScanView.isHidden = false
        qrScanView.startScanningCheckPermission()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        qrScanView.isHidden = true
        qrScanView.stopScanning()
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
                qrCodeView.configure(frames: qrBcur.parts)
            }
        case .xpub:
            navItem.title = ""
            btnTrouble.isHidden = true
            stepView.isHidden = false
            lblStep.isHidden = true
            theme(.dark)
            startCapture()
        }
    }

    func theme(_ theme: Theme) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        
        switch theme {
        case .light:
            imgStep.image = vm.icon(color: .black)
            lblStep.textColor = .gGrayTxt()
            appearance.titleTextAttributes = [.foregroundColor: UIColor.black]
            navBar.tintColor = .black
            btnBack.customView?.tintColor = .black
            lblTitle.textColor = .black
            lblHint.textColor = .gGrayTxt()
            btnNext.setTitleColor(.white, for: .normal)
            view.backgroundColor = .white
        case .dark:
            imgStep.image = vm.icon(color: .white)
            lblStep.textColor = .gGrayTxt()
            appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            navBar.tintColor = .white
            btnBack.customView?.tintColor = .white
            lblTitle.textColor = .white
            lblHint.textColor = .gGrayTxt()
            btnNext.setTitleColor(UIColor.gBlackBg(), for: .normal)
            view.backgroundColor = UIColor.gBlackBg()
        }
        
        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
    }

    func onScanOracle(_ result: ScanResult) async {
        guard let bcur = result.bcur else {
            vm.oracle = result.result
            vm.scope = .handshakeInit
            refresh()
            return
        }
        await onScanHandshakeInit(bcur)
    }

    func onScanHandshakeInit(_ bcur: BcurDecodedData) async {
        do {
            let bcurHandshake = try await vm.jade.qrauth(bcur: bcur)
            await MainActor.run {
                vm.scope = .handshakeInitReply
                qrBcur = bcurHandshake
                refresh()
            }
        } catch {
            showAlert(
                title: "id_error".localized,
                message: error.description().localized) {
                    self.startCapture()
                }
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
            if vm.askXpub {
                vm.scope = .xpub
                refresh()
            } else {
                dismiss(animated: true)
            }
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

    @IBAction func btnBackTapped(_ sender: Any) {
        dismiss(animated: true) {
            self.delegate?.abort()
        }
    }

    @IBAction func btnTroubleTapped(_ sender: Any) {
        SafeNavigationManager.shared.navigate(ExternalUrls.scanQRFixIssues)
    }

    @IBAction func btnNext(_ sender: Any) {
        guard vm.scope == .handshakeInitReply else { return }
        
        if vm.askXpub {
            onScanCompleted(ScanResult.from(result: "", bcur: nil))
        } else {
            dismiss(animated: true)
        }
    }
}

extension QRUnlockJadeViewController: QrScannerViewDelegate {
    func didFindCode(_ code: ScanResult) {
        qrScanView.isHidden = true
        qrScanView.stopScanning()
        onScanResult(code)
    }

    func didUpdateProgress(_ progress: Float) {
        progressView.setProgress(progress)
        progressView.isHidden = false
    }

    func didFailWithError(_ error: String) {
        DropAlert().error(message: error)
    }

    func didChangeAuthorization(isAuthorized: Bool) {
        DropAlert().error(message: "id_please_enable_camera".localized)
    }
}

extension QRUnlockJadeViewController: QRUnlockSuccessAlertViewControllerDelegate {
    func onTap(_ action: QRUnlockSuccessAlertAction) {
        guard let credentials = credentials else { return }
        let isTorActive = AppSettings.shared.gdkSettings?.tor == true
        let torIcon = isTorActive ? UIImage(named: "ic_tor") : nil
        startLoader(message: "id_logging_in".localized, isRive: false, bottomIcon: torIcon)
        Task {
            let task = Task.detached { [weak self] in
                try await self?.vm.exportXpub(enableBio: action == .bio, credentials: credentials)
                return try await self?.vm.login()
            }
            switch await task.result {
            case .success(let wm):
                if let wm {
                    WalletsStorage.shared.current = vm.wallet
                    success(wm: wm, wallet: vm.wallet)
                }
            case .failure(let error):
                failure(error, wallet: vm.wallet)
            }
        }
    }

    @MainActor
    func success(wm: WalletManager, wallet: Wallet) {
        stopLoader()
        dismiss(animated: true) {
            if let credentials = self.credentials {
                WalletsStorage.shared.current = wallet
                self.delegate?.login(credentials: credentials, wm: wm, wallet: wallet)
            }
        }
    }

    @MainActor
    func failure(_ error: Error, wallet: Wallet) {
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
        AnalyticsManager.shared.failedWalletLogin(wallet: wallet, error: error, prettyError: prettyError)
        WalletsRepository.shared.delete(for: wallet)
    }
}
