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
    
    var bleHwManager = BleHwManager.shared
    var scanViewModel: ScanViewModel?
    var version: JadeVersionInfo?
    
    var rememberIsOn = !AppSettings.shared.rememberHWIsOff
    override func viewDidLoad() {
        super.viewDidLoad()

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
            imgDevice.image = UIImage(named: "il_hardware_wallet")
        default:
            imgDevice.image = JadeAsset.img(.normalDual, nil)
        }
        lblHint.text = bleHwManager.type == .Jade ? "Blockstream" : ""
    }
    
    func setStyle() {
        lblTitle.setStyle(.subTitle24)
        lblHint.setStyle(.txtCard)
        btnContinue.setStyle(.primary)
    }
    
    func loadNavigationBtns() {
        let optBtn = UIButton(type: .system)
        optBtn.setImage(UIImage(named: "ic_dots_three"), for: .normal)
        optBtn.addTarget(self, action: #selector(optionsBtnTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItems = [UIBarButtonItem(customView: optBtn)]
    }
    
    @objc func optionsBtnTapped() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {
            vc.delegate = self
            vc.viewModel = DialogListViewModel(title: "Options".localized, type: .walletListPrefs, items: WalletListPrefs.getItems())
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
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
                    if version?.boardType == .v2 || version?.boardType == .v2c {
                        // Perform jade genuine check only for v2 and v2 core
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
        guard let version else { return }
        let storyboard = UIStoryboard(name: "GenuineCheckFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "GenuineCheckDialogViewController") as? GenuineCheckDialogViewController {
            vc.delegate = self
            vc.viewModel = GenuineCheckDialogViewModel(BleHwManager: bleHwManager, board: version.boardType)
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
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
            var account = try await bleHwManager.defaultAccount()
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
    
    func onAbout() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogAboutViewController") as? DialogAboutViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            present(vc, animated: false, completion: nil)
        }
    }
    
    func onAppSettings() {
        let storyboard = UIStoryboard(name: "AppSettings", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "AppSettingsViewController") as? AppSettingsViewController {
            navigationController?.pushViewController(vc, animated: true)
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
        switch type {
        case .walletListPrefs:
            switch index {
            case 0:
                onAppSettings()
            case 1:
                onAbout()
            default:
                break
            }
        case .networkPrefs:
            switch NetworkPrefs(rawValue: index) {
            case .mainnet:
                pushConnectViewController(firstConnection: true, testnet: false)
            case .testnet:
                pushConnectViewController(firstConnection: true, testnet: true)
            case .none:
                break
            }
        default:
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
        guard let version else { return }
        let storyboard = UIStoryboard(name: "GenuineCheckFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "GenuineCheckEndViewController") as? GenuineCheckEndViewController {
            vc.model = GenuineCheckEndViewModel(BleHwManager: BleHwManager.shared, board: version.boardType)
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
            showError(err?.description().localized ?? "id_operation_failure".localized)
        }
    }

    @MainActor
    func presentDialogErrorViewController(error: Error) {
        let request = ZendeskErrorRequest(
            error: error.description().localized,
            network: .bitcoinSS,
            shareLogs: true,
            screenName: "FailedGenuineCheck")
        presentContactUsViewController(request: request)
    }
}

extension PairingSuccessViewController: DialogAboutViewControllerDelegate {
    func openContactUs() {
        presentContactUsViewController(request: ZendeskErrorRequest(shareLogs: true))
    }
}
