import UIKit
import gdk
import CoreBluetooth
import AsyncBluetooth
import Combine
import core

class ScanViewController: HWFlowBaseViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var btnTroubleshoot: UIButton!
    @IBOutlet weak var btnConnectQr: UIButton!
    private var scanCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    var deviceType = DeviceType.Jade
    var scanViewModel: ScanViewModel!
    var account: Account?

    override func viewDidLoad() {
        super.viewDidLoad()

        ["DeviceCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
        if deviceType == .Jade {
            loadNavigationBtns()
        }
        setContent()
        setStyle()
    }

    deinit {
        print("Deinit")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startScan()
        scanCancellable = scanViewModel.objectWillChange.sink(receiveValue: { [weak self] in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        })
        scanViewModel?.centralManager.eventPublisher
            .sink {
                switch $0 {
                case .didUpdateState(let state):
                    DispatchQueue.main.async {
                        self.onCentralManagerUpdateState(state)
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScan()
        scanCancellable?.cancel()
        cancellables.forEach { $0.cancel() }
    }

    @IBAction func tapBtnConnectQr(_ sender: Any) {
        let hwFlow = UIStoryboard(name: "QRUnlockFlow", bundle: nil)
        if let vc = hwFlow.instantiateViewController(withIdentifier: "QRUnlockInfoAlertViewController") as? QRUnlockInfoAlertViewController {
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @MainActor
    func onCentralManagerUpdateState(_ state: CBManagerState) {
        switch state {
        case .poweredOn:
            startScan()
        case .poweredOff:
            showAlert(title: "id_error".localized, message: "id_enable_bluetooth".localized)
            scanViewModel?.reset()
            stopScan()
        default:
            break
        }
    }

    @MainActor
    func startScan() {
        Task {
            do {
                try await scanViewModel?.scan(deviceType: deviceType)
            } catch {
                switch error {
                case BluetoothError.bluetoothUnavailable:
                    self.showAlert(title: "id_error".localized, message: "id_enable_bluetooth".localized)
                default:
                    self.showAlert(title: "id_error".localized, message: error.localizedDescription)
                }
            }
        }
    }

    @MainActor
    func stopScan() {
        Task {
            await scanViewModel?.stopScan()
        }
    }

    func setContent() {
        title = "Devices found".localized
        btnTroubleshoot.setTitle("id_troubleshoot".localized, for: .normal)
        btnConnectQr.setTitle("Connect via QR".localized, for: .normal)
        btnTroubleshoot.isHidden = deviceType != .Jade
    }

    func setStyle() {
        btnTroubleshoot.setStyle(.inline)
        btnConnectQr.setStyle(.outlinedWhite)
    }

    func next() {
        AnalyticsManager.shared.hwwConnected(account: account)
        let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
        if let vc = hwFlow.instantiateViewController(withIdentifier: "PairingSuccessViewController") as? PairingSuccessViewController {
            vc.bleHwManager = BleHwManager.shared
            vc.scanViewModel = scanViewModel
            self.navigationController?.pushViewController(vc, animated: true)
        }
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

    @IBAction func btnTroubleshoot(_ sender: Any) {
        SafeNavigationManager.shared.navigate( ExternalUrls.jadeTroubleshoot )
    }
}

extension ScanViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return scanViewModel.peripherals.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let peripheral = scanViewModel.peripherals[indexPath.row]
        if let cell = tableView.dequeueReusableCell(withIdentifier: DeviceCell.identifier, for: indexPath) as? DeviceCell {
            cell.configure(text: peripheral.name)
            cell.selectionStyle = .none
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.1
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.1
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let peripheral = scanViewModel.peripherals[indexPath.row]
        stopScan()
        startAnimating()
        account = Account(name: peripheral.name, network: NetworkSecurityCase.bitcoinSS, isJade: peripheral.type == .Jade, isLedger: peripheral.type == .Ledger)
        Task {
            do {
                AnalyticsManager.shared.hwwConnect(account: account)
                BleHwManager.shared.type = peripheral.type
                BleHwManager.shared.peripheralID = peripheral.identifier
                try await BleHwManager.shared.connect()
                await MainActor.run {
                    self.stopAnimating()
                    self.next() }
            } catch {
                await MainActor.run {
                    self.stopAnimating()
                    let txt = BleHwManager.shared.toBleError(error, network: nil).localizedDescription
                    self.showError(txt.localized)
                }
            }
        }
    }
}

extension ScanViewController: QRUnlockInfoAlertViewControllerDelegate {
    func onTap(_ action: QRUnlockInfoAlertAction) {
        switch action {
        case .learnMore:
            let url = "https://help.blockstream.com/hc/en-us/sections/10426339090713-Air-gapped-Usage"
            if let url = URL(string: url) {
                if UIApplication.shared.canOpenURL(url) {
                    SafeNavigationManager.shared.navigate(url)
                }
            }
        case .setup:
            let storyboard = UIStoryboard(name: "QRUnlockFlow", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "QRUnlockJadePinInfoViewController") as? QRUnlockJadePinInfoViewController {
                navigationController?.pushViewController(vc, animated: true)
            }
        case .alreadyUnlocked:
            let storyboard = UIStoryboard(name: "QRUnlockFlow", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "QRUnlockJadeViewController") as? QRUnlockJadeViewController {
                vc.vm = QRUnlockJadeViewModel(scope: .xpub, testnet: false)
                vc.delegate = self
                vc.forceUserhelp = true
                vc.modalPresentationStyle = .overFullScreen
                present(vc, animated: true)
            }
        case .cancel:
            break
        }
    }
}

extension ScanViewController: QRUnlockJadeViewControllerDelegate {
    func signerFlow() {
    }

    func login(credentials: gdk.Credentials, wallet: WalletManager) {
        AccountsRepository.shared.current = wallet.account
        AccountNavigator.navLogged(accountId: wallet.account.id)
    }

    func abort() {
        DropAlert().error(message: "id_operation_failure".localized)
    }
}
