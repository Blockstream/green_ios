import Foundation
import AsyncBluetooth
import hw
import gdk
import UIKit
import core

class JadeManager {

    let jade: Jade
    var pinServerSession: SessionManager?
    var walletManager: WalletManager?
    var version: JadeVersionInfo?
    var hash: String?
    var warningPinShowed = false

    var customWhitelistUrls = [String]()
    var persistCustomWhitelistUrls: [String] {
        get { UserDefaults.standard.array(forKey: "whitelist_domains") as? [String] ?? [] }
        set { UserDefaults.standard.setValue(customWhitelistUrls, forKey: "whitelist_domains") }
    }

    func domain(from url: String) -> String? {
        let url = url.starts(with: "http://") || url.starts(with: "https://") ? url : "http://\(url)"
        let urlComponents = URLComponents(string: url)
        if let host = urlComponents?.host {
            if let port = urlComponents?.port {
                return "\(host):\(port)"
            }
            return host
        }
        return nil
    }

    var peripheral: Peripheral? {
        if let connection = jade.connection as? BleJadeConnection {
            return connection.peripheral
        }
        return nil
    }

    var name: String? {
        peripheral?.name
    }

    init(connection: HWConnectionProtocol) {
        jade = Jade(connection: connection)
        jade.gdkRequestDelegate = self
    }

    public func connect() async throws {
        try await jade.connection.open()
    }

    public func disconnect() async throws {
        try await jade.connection.close()
        customWhitelistUrls = []
    }

    public func version() async throws -> JadeVersionInfo {
        let version = try await jade.version()
        self.version = version
        return version
    }

    func connectPinServer(testnet: Bool? = nil) async throws {
        let version = try await version()
        let isTestnet = (testnet == true && version.jadeNetworks == "ALL") || version.jadeNetworks == "TEST"
        let networkType: NetworkSecurityCase = isTestnet ? .testnetSS : .bitcoinSS
        if pinServerSession == nil {
            pinServerSession = SessionManager(networkType.gdkNetwork)
        }
        try await pinServerSession?.connect()
    }

    func authenticating(testnet: Bool? = nil) async throws -> Bool {
        _ = try await jade.addEntropy()
        let version = try await version()
        try? await connectPinServer(testnet: testnet)
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

    func login(account: Account, fullRestore: Bool = false) async throws -> Account {
        let version = try await version()
        let device: HWDevice = .defaultJade(fmwVersion: version.jadeVersion)
        let masterXpub = try await jade.xpubs(network: account.gdkNetwork.chain, path: [])
        let walletId = try? SessionManager(account.gdkNetwork).walletIdentifier(masterXpub: masterXpub)
        var account = account
        account.xpubHashId = walletId?.xpubHashId
        account = normalizeAccount(account)
        let walletManager = WalletsRepository.shared.getOrAdd(for: account)
        walletManager.popupResolver = await PopupResolver()
        walletManager.hwInterfaceResolver = await HwPopupResolver()
        walletManager.hwDevice = device
        walletManager.hwProtocol = jade
        var derivedCredentials: Credentials?
        if let derivedAccount = account.getDerivedLightningAccount() {
            derivedCredentials = try AuthenticationTypeHandler.getAuthKeyLightning(forNetwork: derivedAccount.keychain)
        }
        try await walletManager.loginHW(lightningCredentials: derivedCredentials, device: device, masterXpub: masterXpub, fullRestore: fullRestore)
        walletManager.account.efusemac = version.efusemac
        account = walletManager.account
        self.walletManager = walletManager
        AccountsRepository.shared.current = account
        return account
    }

    func defaultNetwork() async throws -> NetworkSecurityCase {
        let version = try await version()
        return version.jadeNetworks == "TEST" ? .testnetSS : .bitcoinSS
    }

    func normalizeAccount(_ account: Account) -> Account {
        // check existing previous account
        let prevAccount = AccountsRepository.shared.hwAccounts.first { $0.isJade == account.isJade && $0.gdkNetwork == account.gdkNetwork && $0.xpubHashId == account.xpubHashId }
        if var prevAccount = prevAccount {
            prevAccount.name = account.name
            prevAccount.hidden = account.hidden
            return prevAccount
        }
        return account
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
            throw BLEManagerError.timeoutErr(txt: "Something went wrong when pairing Jade. Remove your Jade from iOS bluetooth settings and try again.")
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

extension JadeManager: JadeGdkRequest {
    func bcurEncode(params: Any) async throws -> Any {
        guard let params = params as? BcurEncodeParams else {
            throw BLEManagerError.genericErr(txt: "Invalid bcur")
        }
        let res = try await pinServerSession?.bcurEncode(params: params)
        guard let res = res else {
            throw BLEManagerError.genericErr(txt: "Invalid bcur")
        }
        return res
    }

    @MainActor
    func showUrlValidationWarning(domains: [String], completion: @escaping (UIAlertOption) -> () = { _ in }) {
        if warningPinShowed {
            completion(.continue)
            return
        }
        DispatchQueue.main.async {
            let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
            if let vc = hwFlow.instantiateViewController(withIdentifier: "PinServerWarnViewController") as? PinServerWarnViewController {
                vc.onSupport = {
                    if let url = URL(string: ExternalUrls.pinServerSupport + Common.versionNumber) {
                        SafeNavigationManager.shared.navigate( url )
                    }
                    // navigating info center sends cancel event
                    completion(.cancel)
                }
                vc.onConnect = { [weak self] notAskAgain in
                    self?.warningPinShowed = true
                    self?.customWhitelistUrls += domains
                    if notAskAgain {
                        self?.persistCustomWhitelistUrls += self?.customWhitelistUrls ?? []
                    }
                    completion(.continue)
                }
                vc.onClose = {
                    completion(.cancel)
                }
                vc.domains = domains
                vc.modalPresentationStyle = .overFullScreen
                UIApplication.topViewController()?.present(vc, animated: false, completion: nil)
            }
        }
    }

    @MainActor
    func showTorWarning(domains: [String], completion: @escaping (UIAlertOption) -> () = { _ in }) {
        DispatchQueue.main.async {
            let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
            if let vc = hwFlow.instantiateViewController(withIdentifier: "EnableTorViewController") as? EnableTorViewController {
                vc.onConnect = { () in
                    completion(.continue)
                }
                vc.onClose = { () in
                    completion(.cancel)
                }
                vc.domains = domains
                vc.modalPresentationStyle = .overFullScreen
                UIApplication.topViewController()?.present(vc, animated: false, completion: nil)
            }
        }
    }

    @MainActor
    func showUrlValidationWarning(domains: [String]) async -> UIAlertOption {
        await withCheckedContinuation { continuation in
            showUrlValidationWarning(domains: domains) { result in
                continuation.resume(with: .success(result))
            }
        }
    }

    @MainActor
    func showTorWarning(domains: [String]) async -> UIAlertOption {
        await withCheckedContinuation { continuation in
            showTorWarning(domains: domains) { result in
                continuation.resume(with: .success(result))
            }
        }
    }

    func validateTor(urls: [String]) async -> Bool {
        if urls.allSatisfy({ $0.contains(".onion") || $0.isEmpty }) && AppSettings.shared.gdkSettings?.tor == false {
            switch await showTorWarning(domains: urls) {
            case .continue:
                if AppSettings.shared.gdkSettings?.tor == true {
                    try? await self.pinServerSession?.disconnect()
                    try? await self.pinServerSession?.connect()
                }
                return true
            case .cancel:
                return false
            }
        } else {
            return true
        }
    }

    func urlValidation(urls: [String]) async -> Bool {
        let whitelistUrls = jade.blockstreamUrls + customWhitelistUrls + persistCustomWhitelistUrls
        let whitelistDomains = whitelistUrls.compactMap { domain(from: $0) }
        let domains = urls.filter { !$0.isEmpty }
            .compactMap { domain(from: $0) }
        let isUrlSafe = domains.allSatisfy { domain in whitelistDomains.contains(domain) }
        if isUrlSafe {
            return true
        }
        switch await showUrlValidationWarning(domains: domains) {
        case .continue: return true
        case .cancel: return false
        }
    }

    func httpRequest(params: [String: Any]) async -> [String: Any]? {
        return self.pinServerSession?.httpRequest(params: params)
    }
}
