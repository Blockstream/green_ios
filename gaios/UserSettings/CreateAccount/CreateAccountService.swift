import Foundation
import core
import hw
import greenaddress

enum SubaccountAction {
    case created
    case unarchived
}

struct CreateAccountService {
    let wm: WalletManager
    let mainWallet: Wallet

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

    func create(
        policy: AccountTypeOption,
        params: CreateSubaccountParams,
        isLiquid: Bool,
        shouldCreateNew: @escaping () async -> Bool
    ) async throws -> SubaccountAction {
        let network = policy.getNetwork(testnet: wm.testnet, liquid: isLiquid)!
        let backend = try wm.gdkNetworkBackend(network)
        if !backend.logged {
            try await login(backend: backend)
        }
        let action = try await createOrUnarchiveSubaccount(
            backend: backend,
            params: params,
            shouldCreateNew: shouldCreateNew
        )
        let subaccounts = try await wm.getAccounts()
        _ = try await wm.balances(subaccounts: subaccounts)
        return action
    }

    func login(backend: GdkNetworkBackend) async throws {
        do {
            let credentials = try await getCredentials(networkId: backend.networkId)
            let device = getDevice()
            try await backend.session
                .register(credentials: credentials, hw: device)
            _ = try await backend.login(
                credentials: credentials,
                device: device,
                fullRestore: false,
                creation: true,
                prominentNetworkId: wm.prominentNetworkId)
        } catch {
            switch error {
            case TwoFactorCallError.failure(let txt):
                if txt.contains("HWW must enable host unblinding for singlesig wallets") {
                    try? await backend.disconnect()
                    throw LoginError.hostUnblindingDisabled("Account creation is not possible without exporting master blinding key.")
                }
                throw error
            default:
                throw error
            }
        }
    }

    func createOrUnarchiveSubaccount(
        backend: GdkNetworkBackend,
        params: CreateSubaccountParams,
        shouldCreateNew: @escaping () async -> Bool
    ) async throws -> SubaccountAction {
        let archivedAccounts = try await backend
            .getAccounts(refresh: false)
            .filter {
                $0.type == params.type && $0.type != .twoOfThree && $0.hidden
            }
        /// Check exist an archived account of same type
        if let archivedAccount = archivedAccounts.first {
            if archivedAccount.pointer == 0 {
                try await backend.updateAccount(account: archivedAccount, hidden: false)
                return .created
            } else if await shouldCreateNew() {
                _ = try await backend.createAccount(params: params)
                return .created
            } else {
                try await backend.updateAccount(account: archivedAccount, hidden: false)
                return .unarchived
            }

        }
        /// Create new account
        _ = try await backend.createAccount(params: params)
        return .created
    }
}
