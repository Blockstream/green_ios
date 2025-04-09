import Foundation
import AsyncBluetooth
import hw
import gdk
import core

class BleLedgerManager {

    let bleLedger: BleLedger
    var walletManager: WalletManager?
    var version: String?

    init(bleLedger: BleLedger) {
        self.bleLedger = bleLedger
    }

    public func connect() async throws {
        if !bleLedger.connected {
            try await bleLedger.open()
        }
    }

    public func disconnect() async throws {
        try await bleLedger.close()
    }

    public func version() async throws -> String? {
        let fmw = try await bleLedger.firmware()
        self.version = fmw["version"] as? String
        return self.version
    }

    func getLedgerNetwork() async throws -> NetworkSecurityCase {
        let app = try await bleLedger.application()
        let name = app["name"] as? String ?? ""
        let version = app["version"] as? String ?? ""
        if name.contains("OLOS") {
            throw DeviceError.dashboard // open app from dashboard
        }
        if version >= "2.1.0" && ["Bitcoin", "Bitcoin Test"].contains(name) {
            throw DeviceError.notlegacy_app
        }
        switch name {
        case "Bitcoin", "Bitcoin Legacy":
            return .bitcoinSS
        case "Bitcoin Test", "Bitcoin Test Legacy":
            return .testnetSS
        case "Liquid":
            return .liquidMS
        case "Liquid Test":
            return .testnetLiquidMS
        default:
            throw DeviceError.wrong_app
        }
    }

    func getMasterXpub() async throws -> String {
        let network = try await getLedgerNetwork()
        return try await bleLedger.xpubs(network: network.chain, path: [])
    }

    func authenticating() async throws -> Bool {
        _ = try await getLedgerNetwork()
        return true
    }

    func getHWDevice() async throws -> HWDevice {
        return .defaultLedger()
    }

    func defaultAccount() async throws -> Account {
        let device: HWDevice = .defaultLedger()
        let network = try await getLedgerNetwork()
        return Account(name: bleLedger.peripheral.name ?? device.name,
                       network: network,
                       isJade: device.isJade,
                       isLedger: device.isLedger,
                       isSingleSig: network.gdkNetwork.electrum,
                       uuid: bleLedger.peripheral.identifier,
                       hidden: false,
                       watchonly: false
        )
    }

    func validateAddress(account: WalletItem, addr: Address) async throws -> Bool {
        let network = account.gdkNetwork
        let address = try await bleLedger.newReceiveAddress(chain: network.chain,
                                           mainnet: network.mainnet,
                                           multisig: !network.electrum,
                                           recoveryXPub: account.recoveryXpub,
                                           walletPointer: account.pointer,
                                           walletType: account.type.rawValue,
                                           path: addr.userPath ?? [],
                                           csvBlocks: addr.subtype ?? 0)
        return address == addr.address
    }
}
