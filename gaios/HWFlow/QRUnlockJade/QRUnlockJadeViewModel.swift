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
            return "\("id_step".localized) 3".uppercased()
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
            return UIImage(named: "ic_qr_scan_square")!
        case .handshakeInit:
            return UIImage(named: "ic_qr_scan_square")!
        case .handshakeInitReply:
            return UIImage(named: "ic_qr_scan_shield")!
        case .xpub:
            return UIImage(named: "ic_qr_scan_square")!
        }
    }

    func hint() -> String {
        switch scope {
        case .oracle:
            return "id_initiate_oracle_communication".localized
        case .handshakeInit:
            return "id_validate_pin_and_unlock".localized
        case .handshakeInitReply:
            return "Select ✅ On Jade and then scan this QR".localized
        case .xpub:
            return "Scan your xpub on Jade by Options -> Wallet -> Export Xpub".localized
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
        let wm = WalletsRepository.shared.getOrAdd(for: account)
        let session = wm.prominentSession!
        let password = enableBio ? String.random(length: 14) : ""
        try await session.connect()
        let encrypt = EncryptWithPinParams(pin: password, credentials: credentials)
        let encrypted = try await session.encryptWithPin(encrypt)
        if enableBio {
            try AuthenticationTypeHandler.addBiometry(pinData: encrypted.pinData, extraData: password, forNetwork: account.keychain)
        } else {
            try AuthenticationTypeHandler.addPIN(pinData: encrypted.pinData, forNetwork: account.keychain)
        }
    }

    func login() async throws {
        let wm = WalletsRepository.shared.getOrAdd(for: account)
        let session = wm.prominentSession!
        let bioEnabled = AuthenticationTypeHandler.findAuth(method: .AuthKeyBiometric, forNetwork: account.keychain)
        AnalyticsManager.shared.loginWalletStart()
        let data = try account.auth(bioEnabled ? .AuthKeyBiometric : .AuthKeyPIN)
        try await session.connect()
        let decrypt = DecryptWithPinParams(pin: data.plaintextBiometric ?? "", pinData: data)
        let credentials = try await session.decryptWithPin(decrypt)
        try await wm.loginWatchonly(credentials: credentials)
        AnalyticsManager.shared.loginWalletEnd(account: account, loginType: .watchOnly)
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
