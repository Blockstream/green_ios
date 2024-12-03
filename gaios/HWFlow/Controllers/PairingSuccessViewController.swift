import UIKit
import AsyncBluetooth
import Combine
import core
import hw

class PairingSuccessViewController: HWFlowBaseViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnContinue: UIButton!
    @IBOutlet weak var imgDevice: UIImageView!
    @IBOutlet weak var btnAppSettings: UIButton!

    var bleViewModel: BleViewModel?
    var scanViewModel: ScanViewModel?
    var version: JadeVersionInfo?

    var rememberIsOn = !AppSettings.shared.rememberHWIsOff
    override func viewDidLoad() {
        super.viewDidLoad()

        mash.isHidden = true
        setContent()
        setStyle()
        if bleViewModel?.type == .Jade {
            loadNavigationBtns()
        }
    }

    func setContent() {
        lblTitle.text = bleViewModel?.peripheral?.name
        lblHint.text = "id_follow_the_instructions_on_your".localized
        btnContinue.setTitle("id_continue".localized, for: .normal)
        switch bleViewModel?.type {
        case .Ledger:
            imgDevice.image = UIImage(named: "il_ledger")
        default:
            imgDevice.image = JadeAsset.img(.normalDual, nil)
        }
        lblHint.text = bleViewModel?.type == .Jade ? "Blockstream" : ""
        btnAppSettings.setTitle(NSLocalizedString("id_app_settings", comment: ""), for: .normal)
    }

    func setStyle() {
        lblTitle.font = UIFont.systemFont(ofSize: 24.0, weight: .bold)
        lblTitle.textColor = .white
        [lblHint].forEach {
            $0?.font = UIFont.systemFont(ofSize: 14.0, weight: .regular)
            $0?.textColor = .white
        }
        btnContinue.setStyle(.primary)
        btnAppSettings.setStyle(.inline)
        btnAppSettings.setTitleColor(.white.withAlphaComponent(0.6), for: .normal)
    }

    func loadNavigationBtns() {
        let settingsBtn = UIButton(type: .system)
        settingsBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        settingsBtn.tintColor = UIColor.gGreenMatrix()
        settingsBtn.setTitle("id_setup_guide".localized, for: .normal)
        settingsBtn.addTarget(self, action: #selector(setupBtnTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: settingsBtn)
    }

    @objc func setupBtnTapped() {
        let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
        if let vc = hwFlow.instantiateViewController(withIdentifier: "SetupJadeViewController") as? SetupJadeViewController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    @IBAction func btnContinue(_ sender: Any) {
        startLoader(message: "id_logging_in".localized)
        Task {
            if let scanViewModel = scanViewModel {
                await scanViewModel.stopScan()
            }
            guard let bleViewModel = bleViewModel else {
                return
            }
            do {
                if !bleViewModel.isConnected() {
                    try await bleViewModel.connect()
                }
                try await bleViewModel.ping()

                if bleViewModel.type == .Jade {
                    version = try await bleViewModel.jade?.version()
                    if version?.boardType == .v2 {
                        // Perform jade genuine check only for v2
                        onGenuineCheck()
                    } else {
                        onJadeConnected(jadeHasPin: version?.jadeHasPin ?? true)
                    }
                } else {
                    onLogin()
                }
            } catch {
                try? await bleViewModel.disconnect()
                onError(error)
            }
        }
    }

    @MainActor
    func onGenuineCheck() {
        let storyboard = UIStoryboard(name: "GenuineCheckFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "GenuineCheckDialogViewController") as? GenuineCheckDialogViewController {
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @IBAction func btnAppSettings(_ sender: Any) {
        let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "WalletSettingsViewController") as? WalletSettingsViewController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    @MainActor
    override func onError(_ err: Error) {
        stopLoader()
        let txt = BleViewModel.shared.toBleError(err, network: nil).localizedDescription
        self.showError(txt.localized)
    }

    @MainActor
    func onJadeConnected(jadeHasPin: Bool) {
        startLoader(message: "id_logging_in".localized)
        let testnetAvailable = AppSettings.shared.testnet
        if !jadeHasPin {
            if testnetAvailable {
                self.selectNetwork()
                return
            }
            self.onJadeInitialize(testnet: false)
        } else {
            self.onLogin()
        }
    }

    @MainActor
    func onLogin() {
        Task {
            do {
                let account = try await bleViewModel?.defaultAccount()
                try? await bleViewModel?.disconnect()
                await MainActor.run {
                    stopLoader()
                    var account = account
                    account?.hidden = !(rememberIsOn)
                    let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
                    if let vc = hwFlow.instantiateViewController(withIdentifier: "ConnectViewController") as? ConnectViewController {
                        vc.account = account
                        vc.bleViewModel = bleViewModel
                        vc.scanViewModel = scanViewModel
                        vc.firstConnection = true
                        self.navigationController?.pushViewController(vc, animated: true)
                    }
                }
            } catch {
                try? await bleViewModel?.disconnect()
                stopLoader()
                onError(error)
            }
        }
    }

    @MainActor
    func onJadeInitialize(testnet: Bool) {
        Task {
            await MainActor.run {
                stopLoader()
                let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
                if let vc = hwFlow.instantiateViewController(withIdentifier: "PinCreateViewController") as? PinCreateViewController {
                    vc.testnet = testnet
                    vc.bleViewModel = bleViewModel
                    vc.scanViewModel = scanViewModel
                    vc.remember = rememberIsOn
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
        }
    }
}

extension PairingSuccessViewController: DialogListViewControllerDelegate {
    func didSwitchAtIndex(index: Int, isOn: Bool, type: DialogType) {}

    func selectNetwork() {
        self.stopLoader()
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {
            vc.delegate = self
            vc.viewModel = DialogListViewModel(title: "id_select_network".localized, type: .networkPrefs, items: NetworkPrefs.getItems())
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    func didSelectIndex(_ index: Int, with type: DialogType) {
        switch NetworkPrefs(rawValue: index) {
        case .mainnet:
            onJadeInitialize(testnet: false)
        case .testnet:
            onJadeInitialize(testnet: true)
        case .none:
            break
        }
    }
}

extension PairingSuccessViewController: GenuineCheckDialogViewControllerDelegate {
    func onAction(_ action: GenuineCheckDialogAction) {
        switch action {
        case .cancel:
            stopLoader()
        case .next:
            presentGenuineEndViewController()
        }
    }

    @MainActor
    func presentGenuineEndViewController() {
        let storyboard = UIStoryboard(name: "GenuineCheckFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "GenuineCheckEndViewController") as? GenuineCheckEndViewController {
            vc.model = GenuineCheckEndViewModel(bleViewModel: BleViewModel.shared)
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }
}

extension PairingSuccessViewController: GenuineCheckEndViewControllerDelegate {
    func onTap(_ action: GenuineCheckEndAction) {
        switch action {
        case .cancel, .continue, .diy:
            onJadeConnected(jadeHasPin: version?.jadeHasPin ?? true)
        case .retry:
            presentGenuineEndViewController()
        case .support:
            stopLoader()
            presentDialogErrorViewController(error: HWError.Abort(""))
        case .error(let err):
            stopLoader()
            if let err = err as? HWError {
                switch err {
                case HWError.Disconnected(_):
                    DropAlert().error(message: "id_your_device_was_disconnected".localized)
                    self.navigationController?.popToRootViewController(animated: true)
                    return
                default:
                    break
                }
            }
            let message = err?.description()?.localized
            showError(message ?? "id_operation_failure".localized)
        }
    }

    @MainActor
    func presentDialogErrorViewController(error: Error) {
        let request = DialogErrorRequest(
            account: AccountsRepository.shared.current,
            networkType: .bitcoinSS,
            error: error.description()?.localized ?? "",
            screenName: "FailedGenuineCheck",
            paymentHash: nil)
        if AppSettings.shared.gdkSettings?.tor ?? false {
            self.showOpenSupportUrl(request)
            return
        }
        if let vc = UIStoryboard(name: "Dialogs", bundle: nil)
            .instantiateViewController(withIdentifier: "DialogErrorViewController") as? DialogErrorViewController {
            vc.request = request
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }
}
