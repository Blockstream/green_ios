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
    case exportPsbt(String)
    case signPsbt
}

class QRScanOnJadeViewModel {
    var scope: QRUnlockScope
    var oracle: String?
    let account = Account(name: "Jade", network: .bitcoinSS, isJade: true)
    var jade: QRJadeManager

    init(scope: QRUnlockScope) {
        self.scope = scope
        jade = QRJadeManager(testnet: false)
    }

    func stepTitle() -> String {
        switch scope {
        case .oracle:
            return "Get oracle".localized.uppercased()
        case .handshakeInit:
            return "Step 1 of 3".localized.uppercased()
        case .handshakeInitReply:
            return "Step 2 of 3".localized.uppercased()
        case .xpub:
            return "Export Xpub".localized.uppercased()
        case .exportPsbt(_):
            return "Export Psbt".localized.uppercased()
        case .signPsbt:
            return "Sign Psbt".localized.uppercased()
        }
    }

    func title() -> String {
        switch scope {
        case .oracle:
            return "Scan QR on Jade".localized
        case .handshakeInit:
            return "Scan QR on Jade".localized
        case .handshakeInitReply:
            return "Scan QR with Jade".localized
        case .xpub:
            return "Scan QR on Jade".localized
        case .exportPsbt(_):
            return "Scan Psbt QR with Jade".localized
        case .signPsbt:
            return "Scan Signed Psbt QR on Jade".localized
        }
    }
    
    func icon() -> UIImage {
        switch scope {
        case .oracle:
            return UIImage(named: "ic_jade_qrscan_1")!
        case .xpub:
            return UIImage(named: "ic_jade_qrscan_1")!
        case .handshakeInit:
            return UIImage(named: "ic_jade_qrscan_1")!
        case .handshakeInitReply:
            return UIImage(named: "ic_jade_qrscan_2")!
        case .exportPsbt(_):
            return UIImage(named: "ic_jade_qrscan_2")!
        case .signPsbt:
            return UIImage(named: "ic_jade_qrscan_1")!
        }
    }

    func hint() -> String {
        switch scope {
        case .oracle:
            return "Locate your Jade's blind oracle".localized
        case .handshakeInit:
            return "Press continue on Jade and insert PIN".localized
        case .handshakeInitReply:
            return "Press ✓ on Jade and scan".localized
        case .xpub:
            return "Scan your xpub on Jade by Options -> Wallet -> Export Xpub".localized
        case .exportPsbt(_):
            return "Export Psbt to sign with Jade".localized
        case .signPsbt:
            return "Scan Signed Psbt QR on Jade".localized
        }
    }
    
    func showScanner() -> Bool {
        [.oracle, .handshakeInit, .signPsbt].contains(scope)
    }

    func showQRCode() -> Bool {
        switch scope {
        case .handshakeInitReply, .exportPsbt(_):
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
