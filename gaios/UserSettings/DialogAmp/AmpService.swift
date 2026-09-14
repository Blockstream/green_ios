import Foundation
import core
import greenaddress
import hw

enum RefreshAmpFeature: Sendable, Hashable {
    case success
    case error(String)
}
enum CreateAmpType {
    case v2
    case legacy
}
@MainActor
class AmpService: Sendable {
    var mainWallet: Wallet
    var wm: WalletManager
    private var createTask: Task<Void, Never>?
    private var onUpdate: (@MainActor @Sendable (RefreshAmpFeature?) -> Void)?

    private var lwkNetworkId: NetworkId {
        if wm.testnet {
            return NetworkId.lwkTestnet
        } else {
            return NetworkId.lwkMainnet
        }
    }
    private var gdkGreenLiquidNetworkId: NetworkId {
        if wm.testnet {
            return NetworkId.greenTestnetLiquid
        } else {
            return NetworkId.greenLiquid
        }
    }
    private var gdkGreenLiquidNetworkBackend: GdkNetworkBackend? {
        try? wm.gdkNetworkBackend(gdkGreenLiquidNetworkId)
    }
    private var lwkNetworkBackend: LwkNetworkBackend? {
        try? wm.lwkNetworkBackend(lwkNetworkId)
    }

    private func notifyWalletDataRefresh(networkId: NetworkId) {
        // AMP2 creation is performed via LWK and does not emit GDK newSubaccount events.
        wm.newNotificationDelegate?.didReceive(event: .refreshAssets, networkId: networkId)
    }

    /// AMP2 is limited to software testnet wallets for now.
    /// Hardware, watch-only, and mainnet keep the AMP0 path only.
    var canCreateAmp2: Bool {
        guard wm.testnet else { return false }
        return !mainWallet.isHW && !mainWallet.isWatchonly
    }

    init(mainWallet: Wallet, wm: WalletManager, onUpdate: (@MainActor @Sendable (RefreshAmpFeature?) -> Void)? = nil) {
        self.mainWallet = mainWallet
        self.wm = wm
        self.onUpdate = onUpdate
    }
    func getAmpAccounts() -> [Account] {
        guard canCreateAmp2 else { return [] }
        return lwkNetworkBackend?.accounts.filter { $0.type == .amp2Account } ?? []
    }

    func getLegacyAmpAccounts() -> [Account] {
        return gdkGreenLiquidNetworkBackend?.accounts.filter { $0.type == .ampAccount } ?? []
    }

    func getCredentials(networkId: NetworkId) async throws -> Credentials {
        if mainWallet.isHW {
            let xpub = try await BleHwManager.shared.getMasterXpub(chain: networkId.chain)
            return Credentials(masterXpub: xpub)
        } else {
            if let res = try await wm.prominentNetworkBackend?.session.getCredentials(password: "") {
                return res
            }
            throw GaError.GenericError("Failed to get credentials")
        }
    }
    func getDevice() -> HWDevice? {
        if mainWallet.isJade {
            return HWDevice.defaultJade(fmwVersion: nil)
        } else if mainWallet.isLedger {
            return HWDevice.defaultLedger()
        } else {
            return nil
        }
    }

    func createAmp2Account() async throws {
        guard canCreateAmp2 else {
            throw GaError.GenericError("AMP2 is currently available on testnet software wallets only")
        }
        guard let lwkNetworkBackend else {
            throw GaError.GenericError("No LWK backend")
        }
        _ = try await lwkNetworkBackend
            .createAccount(
                params: CreateSubaccountParams(name: "", type: .amp2Account)
            )
        _ = try await lwkNetworkBackend.getAccounts(refresh: true)
        notifyWalletDataRefresh(networkId: lwkNetworkId)
    }

    func createAmpLegacyAccount() async throws {
        guard let gdkGreenLiquidNetworkBackend else {
            throw GaError.GenericError("No Green Liquid backend")
        }
        if !gdkGreenLiquidNetworkBackend.isConnected {
            let connParams = wm.createConnectionParams(
                network: gdkGreenLiquidNetworkId.gdkNetwork
            )
            try await gdkGreenLiquidNetworkBackend.connect(params: connParams)
        }
        /// If multisig is no registered and 1st login
        if !gdkGreenLiquidNetworkBackend.isLoggedIn {
            let credentials = try await getCredentials(networkId: gdkGreenLiquidNetworkBackend.networkId)
            let device = getDevice()
            try await gdkGreenLiquidNetworkBackend.session.register(credentials: credentials, hw: device)
            _ = try await gdkGreenLiquidNetworkBackend
                .login(
                    credentials: credentials,
                    device: device,
                    fullRestore: false,
                    creation: true,
                    prominentNetworkId: wm.prominentNetworkId
                )
            let accounts = try await gdkGreenLiquidNetworkBackend.getAccounts(
                refresh: false
            )
            // Hide default 1st multisig account
            if let firstAccount = accounts.first {
                try? await wm
                    .gdkAccountBackend(firstAccount)
                    .updateAccount(hidden: true)
            }
        }
        // Create amp0 legacy multisig account
        _ = try await gdkGreenLiquidNetworkBackend
            .createAccount(
                params: CreateSubaccountParams(name: "", type: .ampAccount)
            )
        _ = try await gdkGreenLiquidNetworkBackend.getAccounts(refresh: true)
         notifyWalletDataRefresh(networkId: gdkGreenLiquidNetworkId)
    }

    func onCreate(_ type: CreateAmpType) {
        createTask?.cancel()
        createTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                switch type {
                case .legacy:
                    try await self.createAmpLegacyAccount()
                case .v2:
                    try await self.createAmp2Account()
                }
                guard !Task.isCancelled else { return }
                // Remove watchonly key
                if mainWallet.isJade {
                    removeWatchonlyKeys()
                }
                self.onUpdate?(.success)
            } catch is CancellationError {
                self.onUpdate?(nil)
                return
            } catch {
                self.onUpdate?(.error(error.description()))
            }
        }
    }

    func removeWatchonlyKeys() {
        _ = AuthenticationTypeHandler
            .removeAuth(method: .AuthKeyWoCredentials, for: mainWallet.keychain)
        _ = AuthenticationTypeHandler
            .removeAuth(method: .AuthKeyWoBioCredentials, for: mainWallet.keychain)
    }

    deinit {
        createTask?.cancel()
    }
}
