import Foundation
import core
import greenaddress

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
    var mainWallet: Wallet? { WalletsStorage.shared.current }
    private var createTask: Task<Void, Never>?
    private var onUpdate: (@MainActor @Sendable (RefreshAmpFeature?) -> Void)?

    private var wm: WalletManager { WalletManager.current! }
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
        guard wm.testnet, let mainWallet else { return false }
        return !mainWallet.isHW && !mainWallet.isWatchonly
    }

    init(onUpdate: (@MainActor @Sendable (RefreshAmpFeature?) -> Void)? = nil) {
        self.onUpdate = onUpdate
    }
    func getAmpAccounts() -> [Account] {
        guard canCreateAmp2 else { return [] }
        return lwkNetworkBackend?.accounts.filter { $0.type == .amp2Account } ?? []
    }

    func getLegacyAmpAccounts() -> [Account] {
        return gdkGreenLiquidNetworkBackend?.accounts.filter { $0.type == .ampAccount } ?? []
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
        if !gdkGreenLiquidNetworkBackend.isLoggedIn {
            guard let credentials = try await wm.prominentSession.getCredentials(
                password: ""
            ) else {
                throw GaError.GenericError("No wallet credentials data found")
            }
            try await gdkGreenLiquidNetworkBackend.session.register(credentials: credentials, hw: wm.hwDevice)
            _ = try await gdkGreenLiquidNetworkBackend
                .login(
                    credentials: credentials,
                    device: wm.hwDevice,
                    fullRestore: true,
                    creation: false,
                    prominentNetworkId: wm.prominentNetworkId
                )
            // hide default 2FA subaccounts
            let accounts = try await gdkGreenLiquidNetworkBackend.getAccounts(
                refresh: false
            )
            if let firstAccount = accounts.first {
                try? await wm
                    .gdkAccountBackend(firstAccount)
                    .updateAccount(hidden: true)
            }
        }
        _ = try await gdkGreenLiquidNetworkBackend
            .createAccount(
                params: CreateSubaccountParams(name: "", type: .ampAccount)
            )
        _ = try await gdkGreenLiquidNetworkBackend.getAccounts(refresh: true)
         notifyWalletDataRefresh(networkId: gdkGreenLiquidNetworkId)
    }

    func onCreate(_ type: CreateAmpType) {
        createTask?.cancel()
        createTask = Task { [weak self] in
            guard let self else { return }
            do {
                switch type {
                case .legacy:
                    try await self.createAmpLegacyAccount()
                case .v2:
                    try await self.createAmp2Account()
                }
                guard !Task.isCancelled else { return }
                self.onUpdate?(.success)
            } catch is CancellationError {
                self.onUpdate?(nil)
                return
            } catch {
                self.onUpdate?(.error(error.description()))
            }
        }
    }
    deinit {
        createTask?.cancel()
    }
}
