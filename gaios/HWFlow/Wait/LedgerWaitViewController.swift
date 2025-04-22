import UIKit
import CoreBluetooth
import AsyncBluetooth
import Combine

class LedgerWaitViewController: HWFlowBaseViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!

    var scanViewModel: ScanViewModel?
    private var scanCancellable: AnyCancellable?
    private var selectedItem: ScanListItem?
    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
    }

    deinit {
        print("Deinit")
    }

    override func viewDidAppear(_ animated: Bool) {
        startScan()
        scanViewModel?.centralManager.eventPublisher
            .sink { [weak self] in
                switch $0 {
                case .didUpdateState(let state):
                    DispatchQueue.main.async {
                        self?.onCentralManagerUpdateState(state)
                    }
                default:
                    break
                }
            }.store(in: &cancellables)
        scanCancellable = scanViewModel?.objectWillChange.sink(receiveValue: { [weak self] in
            DispatchQueue.main.async {
                self?.onUpdateScanViewModel()
            }
        })
    }

    override func viewWillDisappear(_ animated: Bool) {
        stopScan()
        scanCancellable?.cancel()
        cancellables.forEach { $0.cancel() }
    }

    @MainActor
    func onUpdateScanViewModel() {
        if selectedItem != nil { return }
        if let peripheral = scanViewModel?.peripherals.filter({ $0.ledger }).first {
            selectedItem = peripheral
            stopScan()
            next()
        }
    }

    @MainActor
    func onCentralManagerUpdateState(_ state: CBManagerState) {
        switch state {
        case .poweredOn:
            startScan()
        case .poweredOff:
            showAlert(title: "id_error".localized, message: "id_enable_bluetooth".localized)
            stopScan()
        default:
            break
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
    func startScan() {
        Task {
            selectedItem = nil
            do {
                try await scanViewModel?.scan(deviceType: .Ledger)
            } catch {
                switch error {
                case BluetoothError.bluetoothUnavailable:
                    showAlert(title: "id_error".localized, message: "id_enable_bluetooth".localized)
                default:
                    showAlert(title: "id_error".localized, message: error.localizedDescription)
                }
                showBleUnavailable()
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
        lblTitle.text = "id_follow_the_instructions_of_your".localized
        lblHint.text = "id_please_follow_the_instructions".localized
    }

    func setStyle() {
        lblTitle.setStyle(.title)
        lblHint.setStyle(.txt)
    }

    func next() {
        let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
        if let vc = hwFlow.instantiateViewController(withIdentifier: "ScanViewController") as? ScanViewController {
            vc.deviceType = .Ledger
            vc.scanViewModel = scanViewModel
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension LedgerWaitViewController: BleUnavailableViewControllerDelegate {
    func onAction(_ action: BleUnavailableAction) {
        navigationController?.popViewController(animated: true)
    }
}
