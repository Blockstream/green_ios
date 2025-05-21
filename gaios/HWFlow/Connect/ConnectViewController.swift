import UIKit
import CoreBluetooth
import AsyncBluetooth
import Combine
import gdk
import hw
import core

enum ConnectionState {
    case watchonly
    case wait
    case scan
    case connect
    case connected
    case auth(JadeVersionInfo?)
    case login
    case logged
    case none
    case error(Error?)
    case firmware(String?)
}

class ConnectViewController: HWFlowBaseViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblSubtitle: UILabel!
    //@IBOutlet weak var image: UIImageView!
    @IBOutlet weak var retryButton: UIButton!
    @IBOutlet weak var retryWoButton: UIButton!
    @IBOutlet weak var progressView: ProgressView!
    private var activeToken, resignToken: NSObjectProtocol?

    var viewModel: ConnectViewModel!

    private var selectedItem: ScanListItem?
    private var isJade: Bool { viewModel.isJade }
    private var hasCredentials: Bool { viewModel.account.hasWoBioCredentials || viewModel.account.hasWoCredentials }

    var state: ConnectionState = .none {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.reload()
            }
        }
    }

    @MainActor
    func reload() {
        switch state {
        case .watchonly:
            progress("id_connecting".localized)
            progressView.isHidden = false
            retryButton.isHidden = true
            retryWoButton.isHidden = true
            progress("")
        case .wait:
            progressView.isHidden = true
            retryButton.isHidden = false
            retryButton.setTitle("id_connect_with_bluetooth".localized, for: .normal)
            retryWoButton.isHidden = !hasCredentials
            if hasCredentials {
                progress("Try Face ID again or enter your PIN to unlock your wallet.")
            } else {
                progress("Enter your PIN to unlock your wallet.")
            }
        case .scan:
            progressView.isHidden = false
            retryButton.isHidden = true
            retryWoButton.isHidden = true
            progress("id_looking_for_device".localized)
        case .connect:
            progressView.isHidden = false
            retryButton.isHidden = true
            retryWoButton.isHidden = true
            progress("id_connecting".localized)
        case .connected:
            progressView.isHidden = false
            retryButton.isHidden = true
            retryWoButton.isHidden = true
            progress("id_connecting".localized)
        case .auth(let version):
            progressView.isHidden = false
            retryButton.isHidden = true
            retryWoButton.isHidden = true
            if !isJade {
                progress("id_connect_your_ledger_to_use_it".localized)
            } else if version?.jadeHasPin ?? false {
                progress("id_unlock_jade_to_continue".localized)
            } else {
                progress("id_enter_and_confirm_a_unique_pin".localized)
            }
            updateImage(version)
        case .login:
            progressView.isHidden = false
            retryButton.isHidden = true
            retryWoButton.isHidden = true
            progress("id_logging_in".localized)
        case .none:
            progressView.isHidden = true
            retryButton.isHidden = true
            retryWoButton.isHidden = true
            progress("")
            updateImage()
        case .logged:
            progressView.isHidden = false
            AccountsRepository.shared.upsert(viewModel.account)
            AccountNavigator.navLogged(accountId: viewModel.account.id)
        case .error(let err):
            progressView.isHidden = true
            retryButton.isHidden = false
            retryWoButton.isHidden = !hasCredentials
            //image.image = UIImage(named: "il_connection_fail")
            if let err = err {
                let txt = viewModel.bleHwManager.toBleError(err, network: nil).localizedDescription
                lblSubtitle.text = txt.localized
                logger.info("error: \(txt)")
            }
        case .firmware(let hash):
            progressView.isHidden = false
            let text = progressLoaderMessage(
                title: "id_updating_firmware".localized,
                subtitle: hash != nil ? "Hash: \(hash ?? "")" : "")
            lblSubtitle.attributedText = text
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setContent()
        setStyle()
        viewModel.updateState = { self.state = $0 }
        viewModel.delegate = self
        if viewModel.autologin {
            Task { [weak self] in
                if self?.hasCredentials ?? false {
                    await self?.loginBiometric()
                } else {
                    await self?.startScan()
                }
            }
        } else {
            state = .wait
        }
    }

    @MainActor
    func setContent() {
        updateImage()
        retryButton.isHidden = true
        retryWoButton.isHidden = true
        retryButton.setTitle("id_connect_with_bluetooth".localized, for: .normal)
        retryWoButton.setTitle("", for: .normal)
        lblTitle.text = viewModel.account.name
        lblSubtitle.text = "Try Face ID again or connect with Bluetooth to access your wallet.".localized
        switch AuthenticationTypeHandler.biometryType {
        case .faceID:
            retryWoButton.setImage(UIImage(systemName: "faceid"), for: .normal)
        case .touchID:
            retryWoButton.setImage(UIImage(systemName: "touchid"), for: .normal)
        default:
            retryWoButton.setImage(UIImage(), for: .normal)
        }
    }

    func setStyle() {
        retryButton.setStyle(.inline)
        lblTitle.setStyle(.title)
        lblSubtitle.setStyle(.txtCard)
        lblSubtitle.numberOfLines = 0
        lblSubtitle.translatesAutoresizingMaskIntoConstraints = false
        retryWoButton.backgroundColor = UIColor.gAccent()
        retryWoButton.cornerRadius = retryWoButton.frame.size.width / 2
    }

    func updateImage(_ version: JadeVersionInfo? = nil) {
        if isJade {
            if let version = version {
                //image.image = JadeAsset.img(.select, version.boardType == .v2 ? .v2 : .v1)
            } else {
                //image.image = JadeAsset.img(.selectDual, nil)
            }
        } else {
            //image.image = UIImage(named: "il_ledger")
        }
    }

    @objc func progressTor(_ notification: NSNotification) {
        if let info = notification.userInfo as? [String: Any],
           let tor = TorNotification.from(info) as? TorNotification {
            progress("id_tor_status".localized + " \(tor.progress)%")
        }
    }

    func onScannedDevice(_ item: ScanListItem) async {
        AnalyticsManager.shared.hwwConnect(account: viewModel.account)
        await viewModel.stopScan()
        viewModel?.type = item.type
        viewModel?.peripheralID = item.identifier
        viewModel.account.uuid = item.identifier
        if !viewModel.firstConnection {
            state = .connect
        }
        let task = Task.detached { [weak self] in
            try await self?.viewModel.connect()
            if await self?.isJade ?? true {
                try await self?.viewModel.loginJade()
            } else {
                try await self?.viewModel.loginLedger()
            }
        }
        switch await task.result {
        case .success:
            if !isJade {
                state = .logged
                return
            }
            // check firmware
            let task = Task.detached { [weak self] in
                try? await self?.viewModel.checkFirmware()
            }
            switch await task.result {
            case .success(let res):
                if let version = res?.0, let lastFirmware = res?.1 {
                    onCheckFirmware(version: version, lastFirmware: lastFirmware)
                } else {
                    state = .logged
                }
            case .failure:
                state = .logged
            }
        case .failure(let error):
            try? await viewModel.bleHwManager.disconnect()
            state = .error(error)
        }
    }

    @MainActor
    func onCheckFirmware(version: JadeVersionInfo, lastFirmware: Firmware) {
        let storyboard = UIStoryboard(name: "HWFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "UpdateFirmwareViewController") as? UpdateFirmwareViewController {
            vc.firmware = lastFirmware
            vc.version = version.jadeVersion
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }

    @IBAction func retryWoBtnTapped(_ sender: Any) {
        Task {
            await loginBiometric()
        }
    }
    @IBAction func retryBtnTapped(_ sender: Any) {
        setContent()
        Task {
            await stopScan()
            await startScan()
        }
    }

    func loginBiometric() async {
        let task = Task.detached { [weak self] in
            try await self?.viewModel.loginJadeWatchonly()
        }
        switch await task.result {
        case .success:
            state = .logged
        case .failure(let error):
            state = .wait
            switch error as? HWError {
            case .Declined:
                break
            case .Disconnected(let error), .InvalidResponse(let error):
                DropAlert().error(message: error.localized)
            default:
                DropAlert().error(message: error.description().localized)
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(progressTor), name: NSNotification.Name(rawValue: EventType.Tor.rawValue), object: nil)
        progressView.isAnimating = true
        activeToken = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main, using: applicationDidBecomeActive)
        resignToken = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main, using: applicationWillResignActive)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: EventType.Tor.rawValue), object: nil)
        Task { [weak self] in
            await self?.stopScan()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        progressView.isAnimating = true
    }

    func applicationWillResignActive(_ notification: Notification) {
    }

    deinit {
        print("deinit")
    }

    @MainActor
    func startScan() async {
        state = .scan
        selectedItem = nil
        do {
            try await viewModel.startScan(deviceType: self.isJade ? .Jade : .Ledger)
        } catch {
            switch error {
            case BluetoothError.bluetoothUnavailable:
                progress("id_enable_bluetooth".localized)
            default:
                progress(error.localizedDescription)
            }
        }
    }

    func showBleUnavailable() {
        var state: BleUnavailableState = .other
        switch CentralManager.shared.bluetoothState {
        case .unauthorized:
            state = .unauthorized
        case .poweredOff:
            state = .powerOff
        default:
            state = .other
        }
        let storyboard = UIStoryboard(name: "BleUnavailable", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "BleUnavailableViewController") as? BleUnavailableViewController {
            vc.state = state
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @MainActor
    func stopScan() async {
        await viewModel.stopScan()
    }

    @MainActor
    func progress(_ txt: String) {
        DispatchQueue.main.async { [weak self] in
            self?.lblSubtitle.text = txt
        }
    }
}

extension ConnectViewController: UpdateFirmwareViewControllerDelegate {
    func didUpdate(version: String, firmware: Firmware) {
        Task {
            do {
                state = .firmware(nil)
                let binary = try await viewModel.bleHwManager.fetchFirmware(firmware: firmware)
                let hash = viewModel.bleHwManager.jade?.jade.sha256(binary)
                let hashHex = hash?.hex.separated(by: " ", every: 8)
                state = .firmware(hashHex)
                let res = try await viewModel.bleHwManager.updateFirmware(firmware: firmware, binary: binary)
                try await viewModel.bleHwManager.disconnect()
                try await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                await startScan()
                await MainActor.run {
                    if res {
                        DropAlert().success(message: "id_firmware_update_completed".localized)
                    } else {
                        DropAlert().error(message: "id_operation_failure".localized)
                    }
                }
            } catch {
                state = .error(error)
            }
        }
    }

    func didSkip() {
        Task {
            state = .logged
        }
    }
}

extension ConnectViewController: BleUnavailableViewControllerDelegate {
    func onAction(_ action: BleUnavailableAction) {
        // navigationController?.popViewController(animated: true)
    }
}
extension ConnectViewController: ConnectViewModelDelegate {
    func onScan(peripherals: [ScanListItem]) {
        if self.selectedItem != nil { return }
        if let item = peripherals.filter({ $0.identifier == self.viewModel.account.uuid || $0.name == self.viewModel.account.name }).first {
            self.selectedItem = item
            Task { [weak self] in
                await self?.onScannedDevice(item)
            }
        }
    }
    func onError(message: String) {
        DropAlert().error(message: message.localized)
    }
    func onUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            switch state {
            case .scan:
                if !viewModel.isScanning {
                    Task { [weak self] in
                        await self?.startScan()
                    }
                }
            default:
                break
            }
        case .poweredOff:
            switch state {
            case .scan:
                if !viewModel.isScanning {
                    progress("id_enable_bluetooth".localized)
                    showBleUnavailable()
                    Task { [weak self] in
                        await self?.stopScan()
                    }
                }
            default:
                break
            }
        default:
            break
        }
    }
}
