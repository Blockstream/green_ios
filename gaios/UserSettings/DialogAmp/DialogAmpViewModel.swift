import Foundation
import core

private enum AmpSectionType {
    case v2
    case legacy

    var createType: CreateAmpType {
        switch self {
        case .v2:
            return .v2
        case .legacy:
            return .legacy
        }
    }

    func title(amp2Enabled: Bool) -> String {
        switch self {
        case .v2:
            return "AMP".localized
        case .legacy:
            // When AMP2 is unavailable, AMP0 is just "AMP" (no Legacy label).
            return amp2Enabled ? "AMP Legacy".localized : "AMP".localized
        }
    }
}

@MainActor
class DialogAmpViewModel: Sendable {

    var mainWallet: Wallet
    var wm: WalletManager
    var service: AmpService?
    var onUpdate: (@MainActor @Sendable (RefreshAmpFeature?) -> Void)?

    init(mainWallet: Wallet, wm: WalletManager, onUpdate: (@MainActor @Sendable (RefreshAmpFeature?) -> Void)? = nil) {
        self.onUpdate = onUpdate
        self.mainWallet = mainWallet
        self.wm = wm
        self.service = AmpService(
            mainWallet: mainWallet,
            wm: wm,
            onUpdate: {[weak self] feature in
            self?.onUpdate?(feature)
        })
    }

    func getAmpAccounts() -> [Account] {
        return service?.getAmpAccounts() ?? []
    }
    func getLegacyAmpAccounts() -> [Account] {
        return service?.getLegacyAmpAccounts() ?? []
    }

    /// Software testnet only. Mainnet / Jade / watch-only stay on AMP0.
    var canCreateAmp2: Bool {
        return service?.canCreateAmp2 ?? false
    }

    private var hasAmp2Account: Bool {
        return !getAmpAccounts().isEmpty
    }

    private var hasLegacyAmpAccount: Bool {
        return !getLegacyAmpAccounts().isEmpty
    }

    private var hasAnyAmpAccount: Bool {
        return hasAmp2Account || hasLegacyAmpAccount
    }

    /// Default primary-button create: AMP2 when allowed, otherwise AMP0.
    var defaultCreateType: CreateAmpType {
        return canCreateAmp2 ? .v2 : .legacy
    }

    private var sectionTypes: [AmpSectionType] {
        guard hasAnyAmpAccount else { return [] }
        if canCreateAmp2 {
            // AMP2 primary path + AMP0 as de-emphasized legacy.
            return [.v2, .legacy]
        }
        // AMP0-only wallets keep the new sheet, without an AMP2 section.
        return [.legacy]
    }

    var sectionCount: Int {
        return sectionTypes.count
    }

    var title: String {
        hasAnyAmpAccount ?
        "AMP Account".localized :
        "Create an AMP Account".localized
    }
    var btnCreateTitle: String {
        return "Create AMP Account".localized
    }
    var hint: String {
        hasAnyAmpAccount ? "Share your AMP ID with your security token issuer for authorization to move funds.".localized : "AMP accounts allow you to send, receive and store managed assets issued on the Liquid Network.".localized
    }
    func cellAmpModels() -> [DialogAmpCellModel] {
        guard canCreateAmp2 else { return [] }
        if !hasAnyAmpAccount {
            return []
        } else if !hasAmp2Account {
            return [DialogAmpCellModel(name: "AMP Liquid".localized, hash: nil)]
        } else {
            return getAmpAccounts().map { account in
                DialogAmpCellModel(name: account.name, hash: account.receivingId)
            }
        }
    }
    func cellAmpLegacyModels() -> [DialogAmpCellModel] {
        if !hasAnyAmpAccount {
            return []
        } else if !hasLegacyAmpAccount {
            // Only offer legacy create when AMP2 is the primary path.
            guard canCreateAmp2 else { return [] }
            return [DialogAmpCellModel(name: "AMP Liquid (Legacy)".localized, hash: nil)]
        } else {
            return getLegacyAmpAccounts().map { account in
                let name = account.name.isEmpty ? "AMP".localized : account.name
                return DialogAmpCellModel(name: name, hash: account.receivingId)
            }
        }
    }

    private func sectionType(at section: Int) -> AmpSectionType? {
        guard section >= 0, section < sectionTypes.count else {
            return nil
        }
        return sectionTypes[section]
    }

    func numberOfRows(in section: Int) -> Int {
        switch sectionType(at: section) {
        case .v2:
            return cellAmpModels().count
        case .legacy:
            return cellAmpLegacyModels().count
        case .none:
            return 0
        }
    }

    func sectionTitle(_ section: Int) -> String {
        return sectionType(at: section)?.title(amp2Enabled: canCreateAmp2) ?? ""
    }

    func cellModel(_ indexPath: IndexPath) -> DialogAmpCellModel {
        switch sectionType(at: indexPath.section) {
        case .v2:
            let models = cellAmpModels()
            return models[indexPath.row]
        case .legacy:
            let models = cellAmpLegacyModels()
            return models[indexPath.row]
        case .none:
            let models = cellAmpLegacyModels()
            return models[indexPath.row]
        }
    }

    func createType(_ indexPath: IndexPath) -> CreateAmpType {
        return sectionType(at: indexPath.section)?.createType ?? .legacy
    }
    func onCreate(_ type: CreateAmpType) {
        service?.onCreate(type)
    }

    func needsBluetoothConnection() -> Bool {
        mainWallet.isJade && (
            !BleHwManager.shared.isConnected() || !BleHwManager.shared.isLogged()
        )
    }

    func hasWatchonlyKey() -> Bool {
        mainWallet.hasWoCredentials || mainWallet.hasWoBioCredentials
    }

    func shouldConfirmWatchonlyExit() -> Bool {
        mainWallet.isJade && hasWatchonlyKey()
    }
}
