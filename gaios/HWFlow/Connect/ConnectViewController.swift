import UIKit
import AsyncBluetooth
import Combine
import gdk
import hw

enum PairingState: Int {
    case unknown
    case pairing
    case paired
}

class ConnectViewController: HWFlowBaseViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var loaderPlaceholder: UIView!
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var retryButton: UIButton!

    var account: Account!
    var bleViewModel: BleViewModel?
    var scanViewModel: ScanViewModel?

    private var activeToken, resignToken: NSObjectProtocol?
    private var pairingState: PairingState = .unknown
    private var selectedItem: ScanListItem?
    private var scanCancellable: AnyCancellable?
    
    let loadingIndicator: ProgressView = {
        let progress = ProgressView(colors: [UIColor.customMatrixGreen()], lineWidth: 2)
        progress.translatesAutoresizingMaskIntoConstraints = false
        return progress
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        loadNavigationBtns()
        scanCancellable = scanViewModel?.objectWillChange.sink(receiveValue: { [weak self] in
            DispatchQueue.main.async {
                if self?.selectedItem != nil { return }
                if let item = self?.scanViewModel?.peripherals.filter({ $0.identifier == self?.account.uuid || $0.name == self?.account.name }).first {
                    self?.selectedItem = item
                    self?.onScannedDevice(item)
                }
            }
        })
    }
    
    func onScannedDevice(_ item: ScanListItem) {
        pairingState = .unknown
        Task {
            do {
                await scanViewModel?.stopScan()
                if bleViewModel?.peripheralID != item.identifier {
                    bleViewModel?.peripheralID = item.identifier
                }
                bleViewModel?.deviceType = .Jade
                progress("id_connecting".localized)
                try? await bleViewModel?.connect()
                if pairingState != .unknown {
                    try? await bleViewModel?.disconnect()
                    try await Task.sleep(nanoseconds:  3 * 1_000_000_000)
                    try await bleViewModel?.connect()
                }
                try await bleViewModel?.ping()
                print("pinged")
                let version = try await bleViewModel?.versionJade()
                if version?.jadeHasPin ?? false {
                    // login
                    progress("id_unlock_jade_to_continue".localized)
                } else {
                    progress("id_follow_the_instructions_on_jade".localized)
                }
                for i in 0..<3 {
                    if let res = try await bleViewModel?.authenticating(), res == true {
                        break
                    } else if i == 2 {
                        throw HWError.Abort("Authentication failure")
                    }
                }
                
                if bleViewModel?.type == .Jade {
                    do {
                        // check firmware
                        let res = try await bleViewModel?.checkFirmware()
                        if let version = res?.0, let lastFirmware = res?.1 {
                            onCheckFirmware(version: version, lastFirmware: lastFirmware)
                            return
                        }
                    } catch {
                        print ("No new firmware found")
                    }
                }
                progress("id_logging_in".localized)
                try await bleViewModel?.login(account: account)
                onLogin(item)
            } catch {
                try? await bleViewModel?.disconnect()
                onError(error)
            }
        }
    }

    @MainActor
    func onLogin(_ item: ScanListItem) {
        print("account.uuid \(account.uuid?.description ?? "")")
        print("peripheral.identifier \(item.identifier)")
        account.uuid = item.identifier
        AccountsRepository.shared.upsert(account)
        AnalyticsManager.shared.hwwConnected(account: account)
        _ = AccountNavigator.goLogged(account: account, nv: navigationController)
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

    func loadNavigationBtns() {
        // Troubleshoot
        let settingsBtn = UIButton(type: .system)
        settingsBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        settingsBtn.tintColor = UIColor.gGreenMatrix()
        settingsBtn.setTitle("id_troubleshoot".localized, for: .normal)
        settingsBtn.addTarget(self, action: #selector(troubleshootBtnTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: settingsBtn)
    }

    @objc func troubleshootBtnTapped() {
        SafeNavigationManager.shared.navigate( ExternalUrls.jadeTroubleshoot )
    }

    @IBAction func retryBtnTapped(_ sender: Any) {
        Task {
            await scanViewModel?.stopScan()
            scanViewModel?.startScan(deviceType: .Jade)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        activeToken = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main, using: applicationDidBecomeActive)
        resignToken = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main, using: applicationWillResignActive)
        scanViewModel?.startScan(deviceType: account.isJade ? .Jade : .Ledger)
    }

    override func viewWillDisappear(_ animated: Bool) {
        if let token = activeToken {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = resignToken {
            NotificationCenter.default.removeObserver(token)
        }
        Task {
            await scanViewModel?.stopScan()
            scanCancellable?.cancel()
        }
    }

    func setContent() {
        if account.isJade {
            image.image = UIImage(named: "il_jade_unlock")
        } else {
            image.image = UIImage(named: "il_ledger")
        }
        retryButton.isHidden = true
        retryButton.setTitle("Retry".localized, for: .normal)
        retryButton.setStyle(.primary)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        print("applicationDidBecomeActive")
        pairingState = .paired
        start()
    }

    func applicationWillResignActive(_ notification: Notification) {
        print("applicationWillResignActive")
        pairingState = .pairing
        stop()
    }

    func setStyle() {
        lblTitle.font = UIFont.systemFont(ofSize: 26.0, weight: .bold)
        lblTitle.textColor = .white
        lblTitle.text = ""
    }

    @MainActor
    func start() {
        loaderPlaceholder.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor
                .constraint(equalTo: loaderPlaceholder.centerXAnchor),
            loadingIndicator.centerYAnchor
                .constraint(equalTo: loaderPlaceholder.centerYAnchor),
            loadingIndicator.widthAnchor
                .constraint(equalToConstant: loaderPlaceholder.frame.width),
            loadingIndicator.heightAnchor
                .constraint(equalTo: loaderPlaceholder.widthAnchor)
        ])

        loadingIndicator.isAnimating = true
    }

    @MainActor
    func stop() {
        loadingIndicator.isAnimating = false
    }

    @MainActor
    func progress(_ txt: String) {
        self.lblTitle.text = txt
    }

    @MainActor
    override func onError(_ err: Error) {
        stop()
        retryButton.isHidden = false
        let bleError = bleViewModel?.toBleError(err, network: nil)
        let txt = bleViewModel?.toErrorString(bleError ?? BLEManagerError.notReady(txt: "id_operation_failure".localized))
        lblTitle.text = txt
        image.image = UIImage(named: "il_connection_fail")
        print ("error: \(bleError)")
    }
}

extension ConnectViewController: UpdateFirmwareViewControllerDelegate {
    @MainActor
    func didUpdate(version: String, firmware: Firmware) {
        startLoader(message: "id_updating_firmware".localized)
        Task {
            do {
                let res = try await bleViewModel?.updateFirmware(firmware: firmware)
                await MainActor.run {
                    self.stopLoader()
                    if let res = res, res {
                        DropAlert().success(message: "id_firmware_update_completed".localized)
                        scanViewModel?.startScan(deviceType: .Jade)
                    } else {
                        DropAlert().error(message: "id_operation_failure".localized)
                    }
                }
            } catch {
                onError(error)
            }
        }
    }

    @MainActor
    func didSkip() {
        Task {
            progress("id_logging_in".localized)
            try await bleViewModel?.login(account: account)
            if let item = selectedItem {
                onLogin(item)
            }
        }
    }

    @MainActor
    func progressLoaderMessage(title: String, subtitle: String) -> NSMutableAttributedString {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white
        ]
        let hashAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.customGrayLight(),
            .font: UIFont.systemFont(ofSize: 16)
        ]
        let hint = "\n\n" + subtitle
        let attributedTitleString = NSMutableAttributedString(string: title)
        attributedTitleString.setAttributes(titleAttributes, for: title)
        let attributedHintString = NSMutableAttributedString(string: hint)
        attributedHintString.setAttributes(hashAttributes, for: hint)
        attributedTitleString.append(attributedHintString)
        return attributedTitleString
    }
}