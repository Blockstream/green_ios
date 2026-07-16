import Foundation
import core
import UIKit
import greenaddress
import hw

enum QRUnlockScope: Equatable {
    case oracle
    case handshakeInit
    case handshakeInitReply
    case xpub
}

class QRUnlockJadeViewModel {
    var scope: QRUnlockScope
    var oracle: String?
    var testnet: Bool
    var wallet: Wallet
    var jade: QRJadeManager
    var askXpub: Bool

    init(scope: QRUnlockScope, testnet: Bool, askXpub: Bool) {
        self.scope = scope
        self.testnet = testnet
        self.askXpub = askXpub
        self.wallet = Wallet(name: "Jade", network: testnet ? .electrumTestnet : .electrumMainnet, isJade: true, watchonly: true)
        jade = QRJadeManager(network: testnet ? .electrumTestnet : .electrumMainnet)
    }

    func stepTitle() -> String {
        switch scope {
        case .oracle:
            return "\("id_step".localized) 1".localized.uppercased()
        case .handshakeInit:
            return "\("id_step".localized) 2".uppercased()
        case .handshakeInitReply:
            return "\("id_step".localized) 2".uppercased()
        case .xpub:
            return ""
        }
    }

    func title() -> String {
        switch scope {
        case .oracle:
            return "id_scan_qr_on_jade".localized
        case .handshakeInit:
            return "id_scan_qr_on_jade".localized
        case .handshakeInitReply:
            return "id_scan_qr_with_jade".localized
        case .xpub:
            return "id_scan_pubkey".localized
        }
    }

    func icon(color: UIColor = .white) -> UIImage {
        switch scope {
        case .oracle:
            return UIImage(named: "ic_qr_scan_square")!.maskWithColor(color: color)
        case .handshakeInit:
            return UIImage(named: "ic_qr_scan_square")!.maskWithColor(color: color)
        case .handshakeInitReply:
            return UIImage(named: "ic_qr_scan_shield")!.maskWithColor(color: color)
        case .xpub:
            return UIImage(named: "ic_qr_scan_square")!.maskWithColor(color: color)
        }
    }

    func hint() -> String {
        switch scope {
        case .oracle:
            return "On Jade select QR Mode > QR PIN Unlock > Continue > Enter your PIN".localized
        case .handshakeInit:
            return "id_on_jade_select_qr__continue_".localized
        case .handshakeInitReply:
            return String(format: "id_select_s_on_jade_and_scan_this".localized, "✅")
        case .xpub:
            return "id_navigate_on_your_jade_to".localized
        }
    }

    func showScanner() -> Bool {
        [.oracle, .handshakeInit].contains(scope)
    }

    func showQRCode() -> Bool {
        switch scope {
        case .handshakeInitReply:
            return true
        default:
            return false
        }
    }

    func exportXpub(enableBio: Bool, credentials: Credentials) async throws {
        try AuthenticationTypeHandler.setCredentials(method: .AuthKeyWoCredentials, credentials: credentials, for: wallet.keychain)
    }

    func getCredentials(wm: WalletManager) async throws -> Credentials {
        if AuthenticationTypeHandler.findAuth(method: .AuthKeyWoCredentials, forNetwork: wallet.keychain) {
            return try AuthenticationTypeHandler.getCredentials(method: .AuthKeyWoCredentials, for: wallet.keychain)
        } else if AuthenticationTypeHandler.findAuth(method: .AuthKeyWoBioCredentials, forNetwork: wallet.keychain) {
            return try AuthenticationTypeHandler.getCredentials(method: .AuthKeyWoBioCredentials, for: wallet.keychain)
        } else {
            let enableBio = AuthenticationTypeHandler.findAuth(method: .AuthKeyBiometric, forNetwork: wallet.keychain)
            AnalyticsManager.shared.loginWalletStart()
            let method: AuthenticationTypeHandler.AuthType = enableBio ? .AuthKeyBiometric : .AuthKeyPIN
            let data = try AuthenticationTypeHandler.getPinData(method: method, for: wallet.keychain)
            guard let session = wm.prominentSession else {
                throw GaError.GenericError("Failed to get session")
            }
            try await session.connect()
            let decrypt = DecryptWithPinParams(pin: data.plaintextBiometric ?? "", pinData: data)
            return try await session.decryptWithPin(decrypt)
        }
    }

    func login() async throws -> WalletManager {
        AnalyticsManager.shared.loginWalletStart()
        let lightningCredentials = try? AuthenticationTypeHandler.getCredentials(method: .AuthKeyLightning, for: wallet.keychainLightning)
        let boltzCredentials = try? AuthenticationTypeHandler.getCredentials(method: .AuthKeyBoltz, for: wallet.keychain)
        let wm = WalletsRepository.shared.getOrAdd(for: wallet)
        let credentials = try await getCredentials(wm: wm)
        let res = try await wm.login(
            credentials: credentials,
            lightningCredentials: lightningCredentials,
            boltzCredentials: boltzCredentials,
            device: nil,
            fullRestore: false,
            creation: false,
            parentXpub: wallet.xpubHashId
        )
        wallet.applyLoginResult(res, credentials: credentials)
        AnalyticsManager.shared.loginWalletEnd(wallet: wallet, loginType: .watchOnly)
        return wm
    }

    func exportPsbt(psbt: String) async throws -> BcurEncodedData {
        let params = BcurEncodeParams(urType: "crypto-psbt", data: psbt)
        guard let res = try await jade.jade.gdkRequestDelegate?.bcurEncode(params: params) as? BcurEncodedData else {
            throw HWError.Abort("Invalid response")
        }
        return res
    }

    func signPsbt(psbt: String) async throws -> BcurEncodedData {
        let params = BcurEncodeParams(urType: "crypto-psbt", data: psbt)
        guard let res = try await jade.jade.gdkRequestDelegate?.bcurEncode(params: params) as? BcurEncodedData else {
            throw HWError.Abort("Invalid response")
        }
        return res
    }
}
