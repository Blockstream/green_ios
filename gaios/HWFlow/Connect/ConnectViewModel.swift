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
    var autologin: Bool = true
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
        type: DeviceType = .Jade,
        autologin: Bool = true) {
            self.account = account
            self.state = state
            self.firstConnection = firstConnection
            self.storeConnection = storeConnection
            self.updateState = updateState
            self.peripherals = peripherals
            self.delegate = delegate
            self.peripheralID = peripheralID
            self.type = type
            self.autologin = autologin
        }

    func startScan(deviceType: DeviceType) async throws {
        if self.centralManager == nil {
            self.centralManager = CBCentralManager(delegate: self, queue: nil)
        }
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
            updateState?(.connected)
        } else {
            _ = try await bleHwManager.ledger?.getLedgerNetwork()
            let version = try await bleHwManager.ledger?.version()
            AnalyticsManager.shared.hwwConnected(
                account: account,
                fwVersion: version ?? "",
                model: "Ledger Nano X")
            updateState?(.connected)
        }
    }
    func loginJade() async throws {
        let version = try await bleHwManager.jade?.version()
        updateState?(.auth(version))
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
        let (account, wm) = try await bleHwManager.login(account: account)
        self.account = account
        AccountsRepository.shared.current = account
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
                _ = try AuthenticationTypeHandler.setCredentials(method: .AuthKeyWoCredentials, credentials: credentials, for: account.keychain)
            } catch {
                logger.error("\(error.description())")
            }
        }
    }

    func checkFirmware() async throws -> (JadeVersionInfo?, Firmware?) {
        try await bleHwManager.checkFirmware()
    }

    func loginLedger() async throws {
        updateState?(.auth(nil))
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
        let (account, wm) = try await bleHwManager.login(account: account)
        // use updated account
        self.account = account
        AccountsRepository.shared.current = account
        if storeConnection {
            WalletsRepository.shared.add(for: account, wm: wm)
        }
    }

    func loginJadeWatchonly(method: AuthenticationTypeHandler.AuthType) async throws {
        updateState?(.watchonly)
        AnalyticsManager.shared.loginWalletStart()
        let wm = WalletManager(prominentNetwork: account.networkType)
        wm.popupResolver = await PopupResolver()
        wm.hwInterfaceResolver = HwPopupResolver()
        switch method {
        case .AuthKeyWoCredentials:
            let credentials = try AuthenticationTypeHandler.getCredentials(method: .AuthKeyWoCredentials, for: account.keychain)
            updateState?(.login)
            let res = try await wm.loginWatchonly(credentials: credentials)
            account.xpubHashId = res?.xpubHashId
            account.walletHashId = res?.walletHashId
        case .AuthKeyWoBioCredentials:
            let credentials = try AuthenticationTypeHandler.getCredentials(method: .AuthKeyWoBioCredentials, for: account.keychain)
            updateState?(.login)
            let res = try await wm.loginWatchonly(credentials: credentials)
            account.xpubHashId = res?.xpubHashId
            account.walletHashId = res?.walletHashId
        case .AuthKeyBiometric, .AuthKeyPIN:
            let session = wm.prominentSession!
            AnalyticsManager.shared.loginWalletStart()
            let data = try AuthenticationTypeHandler.getPinData(method: method, for: account.keychain)
            try await session.connect()
            let decrypt = DecryptWithPinParams(pin: data.plaintextBiometric ?? "", pinData: data)
            let credentials = try await session.decryptWithPin(decrypt)
            updateState?(.login)
            let res = try await wm.loginWatchonly(credentials: credentials)
            account.xpubHashId = res?.xpubHashId
            account.walletHashId = res?.walletHashId
        default:
            throw HWError.Declined("")
        }
        AccountsRepository.shared.current = account
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
