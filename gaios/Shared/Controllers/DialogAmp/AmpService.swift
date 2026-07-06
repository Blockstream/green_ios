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
    case both
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

    init(onUpdate: (@MainActor @Sendable (RefreshAmpFeature?) -> Void)? = nil) {
        self.onUpdate = onUpdate
    }
    func getAmpAccounts() -> [Account] {
        return lwkNetworkBackend?.accounts.filter { $0.isAmp } ?? []
    }

    func getLegacyAmpAccounts() -> [Account] {
        return gdkGreenLiquidNetworkBackend?.accounts.filter { $0.isAmp } ?? []
    }

    func createAmp2Account() async throws {
        guard wm.testnet else {
            throw GaError.GenericError("AMP2 is currently available on testnet only")
        }
        guard let lwkNetworkBackend else {
            throw GaError.GenericError("No LWK backend")
        }
        _ = try await lwkNetworkBackend
            .createAccount(
                params: CreateSubaccountParams(name: "", type: .amp2Account)
            )
        _ = try await lwkNetworkBackend.getAccounts(refresh: false)
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
            try await gdkGreenLiquidNetworkBackend.session.register(credentials: credentials)
            _ = try await gdkGreenLiquidNetworkBackend
                .login(credentials: credentials, device: nil)
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
        _ = try await gdkGreenLiquidNetworkBackend.getAccounts(refresh: false)
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
                    case .both:
                        // we create only amp 2 by default
                        // amp 2 not supported on jade
                        if !(mainWallet?.isJade ?? false) {
                            try await self.createAmp2Account()
                        } else {
                            try await self.createAmpLegacyAccount()
                        }
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
