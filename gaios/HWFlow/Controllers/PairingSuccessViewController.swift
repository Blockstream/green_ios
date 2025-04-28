import UIKit
import AsyncBluetooth
import Combine
import core
import hw
import gdk

class PairingSuccessViewController: HWFlowBaseViewController {
    
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnContinue: UIButton!
    @IBOutlet weak var imgDevice: UIImageView!
    @IBOutlet weak var btnAppSettings: UIButton!
    
    var bleHwManager = BleHwManager.shared
    var scanViewModel: ScanViewModel?
    var version: JadeVersionInfo?
    
    var rememberIsOn = !AppSettings.shared.rememberHWIsOff
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mash.isHidden = true
        setContent()
        setStyle()
        if bleHwManager.type == .Jade {
            loadNavigationBtns()
        }
    }
    
    func setContent() {
        lblTitle.text = bleHwManager.peripheral?.name
        lblHint.text = "id_follow_the_instructions_on_your".localized
        btnContinue.setTitle("id_continue".localized, for: .normal)
        switch bleHwManager.type {
        case .Ledger:
            imgDevice.image = UIImage(named: "il_ledger")
        default:
            imgDevice.image = JadeAsset.img(.normalDual, nil)
        }
        lblHint.text = bleHwManager.type == .Jade ? "Blockstream" : ""
        btnAppSettings.setTitle("id_app_settings".localized, for: .normal)
    }
    
    func setStyle() {
        lblTitle.setStyle(.title)
        lblHint.setStyle(.txt)
        btnContinue.setStyle(.primary)
        btnAppSettings.setStyle(.inline)
        btnAppSettings.setTitleColor(.white.withAlphaComponent(0.6), for: .normal)
    }
    
    func loadNavigationBtns() {
        let settingsBtn = UIButton(type: .system)
        settingsBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        settingsBtn.tintColor = UIColor.gAccent()
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
        Task {
            if let scanViewModel = scanViewModel {
                await scanViewModel.stopScan()
            }
            do {
                if !bleHwManager.isConnected() {
                    try await bleHwManager.connect()
                }
                try await bleHwManager.ping()
                
                if bleHwManager.type == .Jade {
                    version = try await bleHwManager.jade?.version()
                    if version?.boardType == .v2 {
                        // Perform jade genuine check only for v2
                        onGenuineCheck()
                    } else {
                        onJadeConnected(jadeHasPin: version?.jadeHasPin ?? true)
                    }
                } else {
                    self.pushConnectViewController(firstConnection: true)
                }
            } catch {
                try? await bleHwManager.disconnect()
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
        let txt = BleHwManager.shared.toBleError(err, network: nil).localizedDescription
        self.showError(txt.localized)
    }

    @MainActor
    func onJadeConnected(jadeHasPin: Bool) {
        let testnetAvailable = AppSettings.shared.testnet
        if !jadeHasPin {
            if testnetAvailable {
                self.selectNetwork()
                return
            }
            self.pushConnectViewController(firstConnection: true, testnet: false)
        } else {
            self.pushConnectViewController(firstConnection: false)
        }
    }

    @MainActor
    func pushConnectViewController(firstConnection: Bool, testnet: Bool? = nil) {
        Task {
            var account = try? await bleHwManager.defaultAccount()
            try? await bleHwManager.disconnect()
            if let testnet = testnet, testnet {
                account?.networkType = NetworkSecurityCase.testnetSS
            }
            await MainActor.run {
                let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
                if let vc = hwFlow.instantiateViewController(withIdentifier: "ConnectViewController") as? ConnectViewController, let account = account {
                    vc.viewModel = ConnectViewModel(
                        account: account,
                        firstConnection: true,
                        storeConnection: true
                    )
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
        }
    }
}
extension PairingSuccessViewController: DialogListViewControllerDelegate {
    func didSwitchAtIndex(index: Int, isOn: Bool, type: DialogType) {}

    func selectNetwork() {
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
            pushConnectViewController(firstConnection: true, testnet: false)
        case .testnet:
            pushConnectViewController(firstConnection: true, testnet: true)
        case .none:
            break
        }
    }
}

extension PairingSuccessViewController: GenuineCheckDialogViewControllerDelegate {
    func onAction(_ action: GenuineCheckDialogAction) {
        switch action {
        case .cancel:
            break
        case .next:
            presentGenuineEndViewController()
        }
    }

    @MainActor
    func presentGenuineEndViewController() {
        let storyboard = UIStoryboard(name: "GenuineCheckFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "GenuineCheckEndViewController") as? GenuineCheckEndViewController {
            vc.model = GenuineCheckEndViewModel(BleHwManager: BleHwManager.shared)
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
            presentDialogErrorViewController(error: HWError.Abort(""))
        case .error(let err):
            break
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
        let request = ZendeskErrorRequest(
            error: error.description()?.localized ?? "",
            network: .bitcoinSS,
            shareLogs: true,
            screenName: "FailedGenuineCheck")
        if AppSettings.shared.gdkSettings?.tor ?? false {
            self.showOpenSupportUrl(request)
            return
        }
        if let vc = UIStoryboard(name: "HelpCenter", bundle: nil)
            .instantiateViewController(withIdentifier: "ContactUsViewController") as? ContactUsViewController {
            vc.request = request
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: true, completion: nil)
        }
    }
}
