import Foundation
import CoreBluetooth
import core
import gdk
import hw
import AsyncBluetooth

protocol ConnectViewModelDelegate {
    func onScan(peripherals: [ScanListItem])
    func onError(message: String)
    func onUpdateState(_ central: CBCentralManager)
}
class ConnectViewModel: NSObject {
    var account: Account
    var state: ConnectionState = .none
    var firstConnection: Bool = false
    var isJade: Bool { account.isJade }
    var updateState: ((ConnectionState)->())? = nil
    var peripherals: [ScanListItem] = []
    let bleHwManager = BleHwManager.shared
    var delegate: ConnectViewModelDelegate?
    var centralManager: CBCentralManager!
    var peripheralID: UUID? {
        didSet {
            BleHwManager.shared.peripheralID = peripheralID
        }
    }
    var type: DeviceType = .Jade {
        didSet {
            BleHwManager.shared.type = type
        }
    }

    internal init(account: Account, state: ConnectionState = .none, firstConnection: Bool = false, updateState: ((ConnectionState) -> ())? = nil, peripherals: [ScanListItem] = [], delegate: (any ConnectViewModelDelegate)? = nil, peripheralID: UUID? = nil, type: DeviceType = .Jade) {
        self.account = account
        self.state = state
        self.firstConnection = firstConnection
        self.updateState = updateState
        self.peripherals = peripherals
        self.delegate = delegate
        self.peripheralID = peripheralID
        self.type = type
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScan(deviceType: DeviceType) async throws {
        if bleHwManager.centralManager.isScanning {
            return
        }
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
    
    func stopScan() async {
        if bleHwManager.centralManager.isScanning {
            await bleHwManager.centralManager.stopScan()
        }
        peripherals.removeAll()
    }
    
    func peripheral(_ peripheralID: UUID) -> Peripheral? {
        bleHwManager.centralManager.retrievePeripherals(withIdentifiers: [peripheralID]).first
    }
    
    func loginJade() async throws {
        updateState?(.connect)
        if !bleHwManager.isConnected() {
            try await bleHwManager.connect()
        }
        try await bleHwManager.ping()
        let version = try await bleHwManager.jade?.version()
        AnalyticsManager.shared.hwwConnected(
            account: account,
            fwVersion: version?.jadeVersion,
            model: "\(version?.boardType.rawValue ?? "")")
        // authentication
        updateState?(.auth(version))
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
        // export core descriptors for watchonly
        if firstConnection {
            let subaccounts = try await wm.subaccounts()
            let descriptors = subaccounts
                .filter({ !$0.hidden })
                .compactMap({ $0.coreDescriptors })
                .reduce(into: [], { $0 += $1 })
            let credentials = Credentials(coreDescriptors: descriptors)
            _ = try AuthenticationTypeHandler.setCredentials(method: .AuthKeyWoBioCredentials, credentials: credentials, for: account.keychain)
        }
    }
    
    func checkFirmware() async throws-> (JadeVersionInfo?, Firmware?) {
        try await bleHwManager.checkFirmware()
    }
    
    func loginLedger() async throws {
        updateState?(.connect)
        if !bleHwManager.isConnected() {
            _ = try await bleHwManager.connect()
        }
        _ = try await bleHwManager.ledger?.getLedgerNetwork()
        let version = try await bleHwManager.ledger?.version()
        AnalyticsManager.shared.hwwConnected(
            account: account,
            fwVersion: version ?? "",
            model: "Ledger Nano X")
        // authentication
        updateState?(.auth(nil))
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
        _ = try await bleHwManager.login(account: account)
    }
    
    func loginJadeWatchonly() async throws {
        updateState?(.watchonly)
        AnalyticsManager.shared.loginWalletStart()
        let wm = WalletsRepository.shared.getOrAdd(for: account)
        wm.popupResolver = await PopupResolver()
        wm.hwInterfaceResolver = HwPopupResolver()
        let credentials = try? AuthenticationTypeHandler.getCredentials(method: .AuthKeyWoBioCredentials, for: account.keychain)
        guard let credentials = credentials else {
            throw HWError.Declined("")
        }
        let bitcoinDescriptors = credentials.coreDescriptors?.filter({ !$0.hasPrefix("ct")})
        let liquidDescriptors = credentials.coreDescriptors?.filter({ $0.hasPrefix("ct")})
        let lightningCredentials = try? AuthenticationTypeHandler.getCredentials(method: .AuthKeyLightning, for: account.keychain)
        updateState?(.login)
        if let bitcoinDescriptors = bitcoinDescriptors {
            let credentials = Credentials(coreDescriptors: bitcoinDescriptors)
            try? await wm.bitcoinSinglesigSession?.connect()
            _ = try? await wm.bitcoinSinglesigSession?.loginUser(credentials)
        }
        if let liquidDescriptors = liquidDescriptors {
            let credentials = Credentials(coreDescriptors: liquidDescriptors)
            try? await wm.liquidSinglesigSession?.connect()
            _ = try? await wm.liquidSinglesigSession?.loginUser(credentials)
        }
        if let lightningCredentials = lightningCredentials {
            try? await wm.lightningSession?.connect()
            _ = try? await wm.lightningSession?.loginUser(lightningCredentials)
        }
        if bitcoinDescriptors == nil && liquidDescriptors == nil && lightningCredentials == nil {
            throw HWError.Abort("No valid credentials")
        }
        if wm.activeSessions.isEmpty {
            throw HWError.Disconnected("id_you_are_not_connected")
        }
        _ = try await wm.subaccounts()
        try? await wm.loadRegistry()
    }
}

extension ConnectViewModel: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        delegate?.onUpdateState(central)
    }
}
