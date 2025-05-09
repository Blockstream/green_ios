import Foundation
import CoreBluetooth
import UIKit
import core
import hw
import AsyncBluetooth

protocol HWDialogConnectViewControllerDelegate: AnyObject {
    func connected()
    func logged()
    func cancel()
    func failure(err: Error)
}

class HWDialogConnectViewController: UIViewController {

    @IBOutlet weak var icArrow: UIImageView!
    @IBOutlet weak var icWallet: UIImageView!
    @IBOutlet weak var btnDismiss: UIButton!
    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblSubtitle: UILabel!
    @IBOutlet weak var progressView: ProgressView!

    var viewModel: ConnectViewModel?
    var authentication: Bool = true
    var delegate: HWDialogConnectViewControllerDelegate?

    private var selectedItem: ScanListItem?
    private var isJade: Bool { viewModel?.isJade ?? true }
    private var state: ConnectionState = .none {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.reload()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setContent()
        setStyle()
        view.alpha = 0.0
        viewModel = ConnectViewModel(
           account: WalletManager.current!.account,
           firstConnection: false,
           storeConnection: false,
           type: WalletManager.current!.account.isJade ? .Jade : .Ledger
       )
        viewModel?.updateState = { self.state = $0 }
        viewModel?.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
        Task { [weak self] in
            self?.reload()
            if self?.viewModel?.isConnected() ?? false {
                await self?.onLogin()
            } else {
                await self?.startScan()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        Task { [weak self] in
            self?.reload()
            await self?.stopScan()
        }
    }

    func setContent() {
        lblTitle.text = AccountsRepository.shared.current?.name
        lblSubtitle.text = ""
        icArrow.image = UIImage(named: "ic_hww_arrow")!.maskWithColor(color: UIColor.gAccent())
        if viewModel?.isJade ?? true {
            let isV2 = BleHwManager.shared.jade?.version?.boardType == .v2
            icWallet.image = JadeAsset.img(.load, isV2 ? .v2 : .v1)
        } else {
            icWallet.image = UIImage(named: "ic_hww_ledger")
        }
    }

    func setStyle() {
        lblTitle.setStyle(.title)
        lblSubtitle.setStyle(.txt)
        cardView.setStyle(.bottomsheet)
    }

    @MainActor
    func reload() {
        switch state {
        case .wait:
            progress(nil)
        case .scan:
            progress("id_looking_for_device".localized)
        case .connect:
            progress("id_connecting".localized)
        case .auth(let version):
            if !isJade {
                progress("id_connect_your_ledger_to_use_it".localized)
            } else if version?.jadeHasPin ?? false {
                progress("id_unlock_jade_to_continue".localized)
            } else {
                progress("id_enter_and_confirm_a_unique_pin".localized)
            }
        case .login:
            progress("id_logging_in".localized)
        case .none:
            progress(nil)
        case .logged:
            progress(nil)
        case .error:
            progress(nil)
        default:
            progress(nil)
        }
    }

    func dismiss(completion: @escaping () -> ()?) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
            completion()
        })
    }

    @IBAction func btnDismiss(_ sender: Any) {
        dismiss {
            self.delegate?.cancel()
        }
    }

    @MainActor
    func startScan() async {
        state = .scan
        selectedItem = nil
        do {
            try await viewModel?.startScan(deviceType: isJade ? .Jade : .Ledger)
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
        await viewModel?.stopScan()
    }

    @MainActor
    func progress(_ txt: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.lblSubtitle.text = txt
            //self?.progressView.isHidden = txt == nil
            self?.progressView.isAnimating = !(self?.progressView.isHidden ?? false)
        }
    }

    func onScannedDevice(_ item: ScanListItem) {
        viewModel?.type = item.type
        viewModel?.peripheralID = item.identifier
        viewModel?.account.uuid = item.identifier
        Task { [weak self] in
            await self?.viewModel?.stopScan()
            await self?.onLogin()
        }
    }
    func onLogin() async {
        let task = Task.detached { [weak self] in
            try await self?.viewModel?.connect()
            if await self?.authentication ?? true {
                if await self?.isJade ?? true {
                    try await self?.viewModel?.loginJade()
                } else {
                    try await self?.viewModel?.loginLedger()
                }
            }
        }
        switch await task.result {
        case .success:
            if authentication {
                state = .logged
                dismiss {
                    self.delegate?.logged()
                }
            } else {
                state = .auth(nil)
                dismiss {
                    self.delegate?.connected()
                }
            }
        case .failure(let error):
            try? await viewModel?.bleHwManager.disconnect()
            state = .error(error)
            dismiss {
                self.delegate?.failure(err: error)
            }
        }
    }
}

extension HWDialogConnectViewController: ConnectViewModelDelegate {
    func onScan(peripherals: [ScanListItem]) {
        if self.selectedItem != nil { return }
        if let item = peripherals.filter({ $0.identifier == self.viewModel?.account.uuid || $0.name == self.viewModel?.account.name }).first {
            self.selectedItem = item
            self.onScannedDevice(item)
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
                if !(viewModel?.isScanning ?? false) {
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
                if viewModel?.isScanning ?? false {
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

extension HWDialogConnectViewController: BleUnavailableViewControllerDelegate {
    func onAction(_ action: BleUnavailableAction) {
        // navigationController?.popViewController(animated: true)
    }
}
