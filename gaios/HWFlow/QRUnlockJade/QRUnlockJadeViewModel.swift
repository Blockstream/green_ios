import Foundation
import core
import UIKit
import gdk
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
    let account: Account
    var jade: QRJadeManager

    init(scope: QRUnlockScope, testnet: Bool) {
        self.scope = scope
        self.testnet = testnet
        self.account = Account(name: "Jade", network: testnet ? .testnetSS : .bitcoinSS, isJade: true, watchonly: true)
        jade = QRJadeManager(testnet: testnet)
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
            return "Export Xpub".localized.uppercased()
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
            return "id_scan_qr_on_jade".localized
        }
    }

    func icon() -> UIImage {
        switch scope {
        case .oracle:
            return UIImage(named: "ic_qr_scan_square")!.maskWithColor(color: UIColor.gAccent())
        case .handshakeInit:
            return UIImage(named: "ic_qr_scan_square")!.maskWithColor(color: UIColor.gAccent())
        case .handshakeInitReply:
            return UIImage(named: "ic_qr_scan_shield")!.maskWithColor(color: UIColor.gAccent())
        case .xpub:
            return UIImage(named: "ic_qr_scan_square")!.maskWithColor(color: UIColor.gAccent())
        }
    }

    func hint() -> String {
        switch scope {
        case .oracle:
            return "id_on_jade_select_qr__continue_".localized
        case .handshakeInit:
            return "id_on_jade_select_qr__continue_".localized
        case .handshakeInitReply:
            return String(format: "id_select_s_on_jade_and_scan_this".localized, "✅")
        case .xpub:
            return "id_get_watchonly_information_from".localized
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
        try AuthenticationTypeHandler.setCredentials(method: .AuthKeyWoCredentials, credentials: credentials, for: account.keychain)
    }

    func login() async throws -> WalletManager {
        AnalyticsManager.shared.loginWalletStart()
        let wm = WalletsRepository.shared.getOrAdd(for: account)
        if AuthenticationTypeHandler.findAuth(method: .AuthKeyWoCredentials, forNetwork: account.keychain) {
            let credentials = try AuthenticationTypeHandler.getCredentials(method: .AuthKeyWoCredentials, for: account.keychain)
            try await wm.loginWatchonly(credentials: credentials)
        } else if AuthenticationTypeHandler.findAuth(method: .AuthKeyWoBioCredentials, forNetwork: account.keychain) {
            let credentials = try AuthenticationTypeHandler.getCredentials(method: .AuthKeyWoBioCredentials, for: account.keychain)
            try await wm.loginWatchonly(credentials: credentials)
        } else {
            let session = wm.prominentSession!
            let enableBio = AuthenticationTypeHandler.findAuth(method: .AuthKeyBiometric, forNetwork: account.keychain)
            AnalyticsManager.shared.loginWalletStart()
            let method: AuthenticationTypeHandler.AuthType = enableBio ? .AuthKeyBiometric : .AuthKeyPIN
            let data = try AuthenticationTypeHandler.getPinData(method: method, for: account.keychain)
            try await session.connect()
            let decrypt = DecryptWithPinParams(pin: data.plaintextBiometric ?? "", pinData: data)
            let credentials = try await session.decryptWithPin(decrypt)
            try await wm.loginWatchonly(credentials: credentials)
        }
        AnalyticsManager.shared.loginWalletEnd(account: account, loginType: .watchOnly)
        return wm
    }

    func exportPsbt(psbt: String) async throws -> BcurEncodedData {
        let params = BcurEncodeParams(urType: "crypto-psbt", data: psbt)
        guard let res = try await jade.device?.gdkRequestDelegate?.bcurEncode(params: params) as? BcurEncodedData else {
            throw HWError.Abort("Invalid response")
        }
        return res
    }

    func signPsbt(psbt: String) async throws -> BcurEncodedData {
        let params = BcurEncodeParams(urType: "crypto-psbt", data: psbt)
        guard let res = try await jade.device?.gdkRequestDelegate?.bcurEncode(params: params) as? BcurEncodedData else {
            throw HWError.Abort("Invalid response")
        }
        return res
    }
}
