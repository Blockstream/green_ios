import Foundation
import AsyncBluetooth
import hw
import gdk
import UIKit
import core

class BleJadeManager: JadeManager {

    var version: JadeVersionInfo?
    var hash: String?

    var peripheral: Peripheral? {
        if let connection = jade.connection as? BleJadeConnection {
            return connection.peripheral
        }
        return nil
    }

    var name: String? {
        peripheral?.name
    }

    public func connect() async throws {
        try await jade.connection.open()
    }

    public override func disconnect() async throws {
        try await jade.connection.close()
        try await super.disconnect()
    }

    public func version() async throws -> JadeVersionInfo {
        let version = try await jade.version()
        self.version = version
        return version
    }
    
    public func isTestnet() async throws -> Bool {
        if version == nil {
            _ = try await version()
        }
        return version?.jadeNetworks == "TEST"
        
    }
/*
    override func connectPinServer(testnet: Bool? = nil) async throws {
        if pinServerSession == nil {
            if version == nil {
                _ = try await version()
            }
            let isTestnet = (testnet == true && version?.jadeNetworks == "ALL") || version?.jadeNetworks == "TEST"
            let networkType: NetworkSecurityCase = isTestnet ? .testnetSS : .bitcoinSS
            pinServerSession = SessionManager(networkType.gdkNetwork)
        }
        try await pinServerSession?.connect()
    }
*/
    func getMasterXpub(chain: String ) async throws -> String {
        let version = try await version()
        let _: HWDevice = .defaultJade(fmwVersion: version.jadeVersion)
        return try await jade.xpubs(network: chain, path: [])
    }

    func authenticating(testnet: Bool? = nil) async throws -> Bool {
        _ = try await jade.addEntropy()
        let version = try await version()
        let testnet = try await isTestnet()
        try await connectPinServer(testnet: testnet)
        let chain = pinServerSession?.gdkNetwork.chain ?? "mainnet"
        switch version.jadeState {
        case "READY":
            return true
        case "TEMP":
            return try await jade.unlock(network: chain)
        default:
            return try await jade.auth(network: chain)
        }
    }

    func silentMasterBlindingKey() async throws -> Bool {
        do {
            _ = try await jade.getMasterBlindingKey(onlyIfSilent: true)
            return true
        } catch {
            return false
        }
    }

    func defaultNetwork() async throws -> NetworkSecurityCase {
        let version = try await version()
        return version.jadeNetworks == "TEST" ? .testnetSS : .bitcoinSS
    }

    func getHWDevice() async throws -> HWDevice {
        let version = try await version()
        return .defaultJade(fmwVersion: version.jadeVersion)
    }

    func defaultAccount() async throws -> Account {
        let version = try await version()
        let device: HWDevice = .defaultJade(fmwVersion: version.jadeVersion)
        let network = try await defaultNetwork()
        return Account(name: name ?? device.name,
                       network: network,
                       isJade: device.isJade,
                       isLedger: device.isLedger,
                       isSingleSig: network.gdkNetwork.electrum,
                       uuid: peripheral?.identifier,
                       hidden: false)
    }

    func checkFirmware() async throws -> (JadeVersionInfo?, Firmware?) {
        let version = try await version()
        let fmw = try await jade.firmwareData(version)
        return (version, fmw)
    }

    func fetchFirmware(firmware: Firmware) async throws -> Data {
        let version = try await version()
        let binary = try await jade.getBinary(version, firmware)
        // hash = jade.sha256(binary).hex
        return binary
    }

    func updateFirmware(firmware: Firmware, binary: Data) async throws -> Bool {
        let version = try await version()
        let updated = try await jade.updateFirmware(version: version, firmware: firmware, binary: binary)
        return updated
    }

    func validateAddress(account: WalletItem, addr: Address) async throws -> Bool {
        let network = account.gdkNetwork
        let address = try await jade.newReceiveAddress(chain: network.chain,
                                           mainnet: network.mainnet,
                                           multisig: !network.electrum,
                                           recoveryXPub: account.recoveryXpub,
                                           walletPointer: account.pointer,
                                           walletType: account.type.rawValue,
                                           path: addr.userPath ?? [],
                                           csvBlocks: addr.subtype ?? 0)
        return address == addr.address
    }

    func ping() async throws -> JadeVersionInfo {
        let versionTask = Task {
            try await self.version()
        }
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 3 * 1_000_000_000)
            versionTask.cancel()
        }
        do {
            let version = try await versionTask.value
            timeoutTask.cancel()
            return version
        } catch {
            throw BLEManagerError.timeoutErr(txt: "id_something_went_wrong_when".localized)
        }
    }

    func genuineCheck() async throws -> Bool {
        let extPubKey = "-----BEGIN PUBLIC KEY-----\n" +
        "MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAyBnvF2+06j87PL4GztOf\n" +
        "6OVPXoHObwU/fV3PJDWAY1kpWO2MRQUaM7xtb+XwEzt+Vw9it378nCVvREJ/4IWQ\n" +
        "uVO8qQn2V1eASIoRtfM5HjERRtL4JUc7D1U2Vr4ecJEhQ1nSQuhuU9N2noo/tTxX\n" +
        "nYIMiFOBJNPqzjWr9gTzcLdE23UjpasKMKyWEVPw0AGWl/aOGo8oAaGYjqB870s4\n" +
        "29FBJeqOpaTHZqI/xp9Ac+R8gCP6H77vnSHGIxyZBIfcoPc9AFL83Ch0ugPLMQDf\n" +
        "BsUzfi8gANHp6tKAjrH00wgHV1JC1hT7BRHffeqh9Tc7ERUmxg06ajBZf0XdWbIr\n" +
        "tpNs6/YZJbv4S8+0VP9SRDOYigOuv/2nv16RyMO+TphH6PvwLQoRGixswICT2NBh\n" +
        "oqTDi2kIwse51EYjLZ5Wi/n5WH+YtKs0O5cVY+0/mUMvknD7fBPv6+rvOr0OZu28\n" +
        "1Qi+vZuP8it3qIdYybNmyD2FMGsYOb2OkIG2JC5GSn7YGwc+dRa87DGrG7S4rh4I\n" +
        "qRCB9pudTntGoQNhs0G9aNNa36sUSp+FUAPB8r55chmQPVDv2Uqt/2cpfgy/UIPE\n" +
        "DvMN0FWJF/3y6x0UOJiNK3VJKjhorYi6dRuJCmk6n+BLXHCaYvfLD7mEp0IEapo7\n" +
        "VTWr98cwCwEqT+NTHm2FaNMCAwEAAQ==\n" +
        "-----END PUBLIC KEY-----"
        let session = SessionManager(NetworkSecurityCase.bitcoinSS.gdkNetwork)
        try? await session.connect()
        let challenge = try Data.random(length: 32)
        let signAttestationResult = try await jade.signAttestation(JadeSignAttestation(challenge: challenge))
        let verifyAttestationJade = RSAVerifyParams(pem: signAttestationResult.pubkeyPem, challenge: challenge.hex, signature: signAttestationResult.signature.hex)
        let verifiedAttestationJade = try? await session.rsaVerify(details: verifyAttestationJade)
        let pemChallenge = signAttestationResult.pubkeyPem.toData() ?? Data()
        let verifyAttestation = RSAVerifyParams(pem: extPubKey, challenge: pemChallenge.hex, signature: signAttestationResult.extSignature.hex)
        let verifiedAttestation = try? await session.rsaVerify(details: verifyAttestation)
        return verifiedAttestationJade?.result ?? false && verifiedAttestation?.result ?? false
    }
}
