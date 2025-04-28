import Foundation
import CoreBluetooth
import core
import gdk
import hw
import AsyncBluetooth

protocol ConnectViewModelDelegate: AnyObject {
    func onScan(peripherals: [ScanListItem])
    func onError(message: String)
    func onUpdateState(_ central: CBCentralManager)
}

class ConnectViewModel: NSObject {

    var account: Account
    var firstConnection: Bool = false
    var storeConnection: Bool = true

    var isScanning: Bool = false
    var state: ConnectionState = .none
    var isJade: Bool { account.isJade }
    var updateState: ((ConnectionState)->())?
    var peripherals: [ScanListItem] = []
    var bleHwManager: BleHwManager { BleHwManager.shared }
    var delegate: ConnectViewModelDelegate?
    var centralManager: CBCentralManager!
    var peripheralID: UUID? {
        didSet {
            bleHwManager.peripheralID = peripheralID
        }
    }
    var type: DeviceType = .Jade {
        didSet {
            bleHwManager.type = type
        }
    }

    internal init(
        account: Account,
        firstConnection: Bool,
        storeConnection: Bool,
        state: ConnectionState = .none,
        updateState: ((ConnectionState) -> ())? = nil,
        peripherals: [ScanListItem] = [],
        delegate: (any ConnectViewModelDelegate)? = nil,
        peripheralID: UUID? = nil,
        type: DeviceType = .Jade) {
        self.account = account
        self.state = state
        self.firstConnection = firstConnection
        self.storeConnection = storeConnection
        self.updateState = updateState
        self.peripherals = peripherals
        self.delegate = delegate
        self.peripheralID = peripheralID
        self.type = type
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScan(deviceType: DeviceType) async throws {
        if isScanning {
            return
        }
        isScanning = true
        try await bleHwManager.centralManager.waitUntilReady()
        let uuid = deviceType == .Jade ? BleJadeConnection.SERVICE_UUID : BleLedger.SERVICE_UUID
        let service = CBUUID(string: uuid.uuidString)
        let connectedPeripherals = bleHwManager.centralManager.retrieveConnectedPeripherals(withServices: [service])
        connectedPeripherals.forEach { addPeripheral($0, for: deviceType) }
        let scanDataStream = try await bleHwManager.centralManager.scanForPeripherals(withServices: [service])
        for await scanData in scanDataStream {
            self.addPeripheral(scanData.peripheral, for: deviceType)
        }
    }

    func addPeripheral(_ peripheral: Peripheral, for deviceType: DeviceType) {
        let identifier = peripheral.identifier
        let name = peripheral.name ?? ""
        let peripheral = ScanListItem(identifier: identifier, name: name, type: deviceType)
        if peripheral.type == deviceType {
            if peripherals.contains(where: { $0.identifier == identifier || $0.name == name }) {
                peripherals.removeAll(where: { $0.identifier == identifier || $0.name == name })
            }
            peripherals.append(peripheral)
            delegate?.onScan(peripherals: peripherals)
        }
    }

    func isConnected() -> Bool {
        bleHwManager.isConnected()
    }

    func stopScan() async {
        if bleHwManager.centralManager.isScanning {
            await bleHwManager.centralManager.stopScan()
        }
        peripherals.removeAll()
        isScanning = false
    }

    func peripheral(_ peripheralID: UUID) -> Peripheral? {
        bleHwManager.centralManager.retrievePeripherals(withIdentifiers: [peripheralID]).first
    }
    func connect() async throws {
        await stopScan()
        updateState?(.connect)
        if bleHwManager.isConnected() {
            return
        }
        try await bleHwManager.connect()
        if isJade {
            try await bleHwManager.ping()
            let version = try await bleHwManager.jade?.version()
            AnalyticsManager.shared.hwwConnected(
                account: account,
                fwVersion: version?.jadeVersion,
                model: "\(version?.boardType.rawValue ?? "")")
            updateState?(.auth(version))
        } else {
            _ = try await bleHwManager.ledger?.getLedgerNetwork()
            let version = try await bleHwManager.ledger?.version()
            AnalyticsManager.shared.hwwConnected(
                account: account,
                fwVersion: version ?? "",
                model: "Ledger Nano X")
            updateState?(.auth(nil))
        }
    }
    func loginJade() async throws {
        // authentication
        for i in 0..<3 {
            let res = try await bleHwManager.authenticating(testnet: account.networkType.testnet)
            if res == true {
                break
            } else if i == 2 {
                throw HWError.Abort("Authentication failure")
            }
        }
        // check silently master blinding key
        _ = try await bleHwManager.jade?.silentMasterBlindingKey()
        // login
        updateState?(.login)
        let wm = try await bleHwManager.login(account: account)
        if storeConnection {
            WalletsRepository.shared.add(for: account, wm: wm)
        }
        // export core descriptors for watchonly
        if firstConnection && wm.activeMultisigSessions.isEmpty {
            let subaccounts = try await wm.subaccounts()
            let descriptors = subaccounts
                .filter({ !$0.hidden })
                .compactMap({ $0.coreDescriptors })
                .reduce(into: [], { $0 += $1 })
            let credentials = Credentials(coreDescriptors: descriptors)
            do {
                _ = try AuthenticationTypeHandler.setCredentials(method: .AuthKeyWoBioCredentials, credentials: credentials, for: account.keychain)
            } catch {
                _ = try AuthenticationTypeHandler.setCredentials(method: .AuthKeyWoCredentials, credentials: credentials, for: account.keychain)
            }
        }
    }

    func checkFirmware() async throws -> (JadeVersionInfo?, Firmware?) {
        try await bleHwManager.checkFirmware()
    }

    func loginLedger() async throws {
        // authentication
        for i in 0..<3 {
            let res = try await bleHwManager.authenticating()
            if res == true {
                break
            } else if i == 2 {
                throw HWError.Abort("Authentication failure")
            }
        }
        // login
        updateState?(.login)
        let wm = try await bleHwManager.login(account: account)
        if storeConnection {
            WalletsRepository.shared.add(for: account, wm: wm)
        }
    }

    func loginJadeWatchonly() async throws {
        updateState?(.watchonly)
        AnalyticsManager.shared.loginWalletStart()
        let wm = WalletManager(account: account, prominentNetwork: account.networkType)
        wm.popupResolver = await PopupResolver()
        wm.hwInterfaceResolver = HwPopupResolver()
        let method: AuthenticationTypeHandler.AuthType = account.hasWoBioCredentials ? .AuthKeyWoBioCredentials : .AuthKeyWoCredentials
        let credentials = try? AuthenticationTypeHandler.getCredentials(
            method: method,
            for: account.keychain)
        guard let credentials = credentials else {
            throw HWError.Declined("")
        }
        let lightningCredentials = try? AuthenticationTypeHandler.getCredentials(
            method: .AuthKeyLightning,
            for: account.keychain)
        updateState?(.login)
        try await wm.logiHwWatchonly(
            credentials: credentials,
            lightningCredentials: lightningCredentials)
        if storeConnection {
            WalletsRepository.shared.add(for: account, wm: wm)
        }
    }
}

extension ConnectViewModel: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        delegate?.onUpdateState(central)
    }
}
